# `helm upgrade` failing or rolling out badly

## Triage

```bash
helm history $RELEASE -n $NS
kubectl -n $NS rollout status deploy/<release>-be-studio-api  # or any service
kubectl -n $NS get events --sort-by=.lastTimestamp | tail -30
```

## Common cases

### Image tag bumped but pull fails
**Symptom.** New ReplicaSet stuck pulling, old pods still serving.

**Fix.** Roll back, fix the tag, retry:
```bash
helm rollback $RELEASE -n $NS
# Verify the tag exists in registry, then upgrade again.
```

### `metadata-service` rolling update deadlocks
**Symptom.** `<release>-be-metadata-service` has 1 replica, can't roll new pod because PVC is `ReadWriteOnce`.

**Cause.** Known issue — `metadata-service` is a Deployment with a PVC; the new pod can't bind until the old one releases. See ADR-006.

**Fix (workaround).** Scale to 0, wait for PVC release, scale back:
```bash
kubectl -n $NS scale deploy/<release>-be-metadata-service --replicas=0
kubectl -n $NS wait --for=delete pod -l app.kubernetes.io/name=<release>-be-metadata-service --timeout=60s
helm upgrade ...
```

### Temporal `schema-update` Job fails after upgrade
**Symptom.** Upgrade hangs on Temporal hook.

**Cause.** Postgres credentials changed but the existing Job hook didn't pick up the new secret, or temporal version requires a schema migration.

**Fix.**
```bash
kubectl -n $NS logs job/<release>-temporal-schema-update
# Common: "FATAL: password authentication failed". Restart with hooks deleted:
kubectl -n $NS delete job <release>-temporal-schema-update
helm upgrade ... --force
```

### Traefik CRD version mismatch
**Symptom.** `IngressRoute` resource validation failures after upgrade.

**Cause.** Traefik subchart bumped between chart versions; old CRDs in cluster.

**Fix.** Re-apply CRDs:
```bash
kubectl apply --server-side --force-conflicts -k https://github.com/traefik/traefik-helm-chart/traefik/crds/
```

### Helm `another operation in progress`
**Symptom.** `Error: another operation (install/upgrade/rollback) is in progress`.

**Fix.**
```bash
helm history $RELEASE -n $NS
# If a previous upgrade is hung in pending-upgrade:
helm rollback $RELEASE <previous-revision> -n $NS
# Or, hard mark as failed:
kubectl -n $NS patch secret sh.helm.release.v1.$RELEASE.v<rev> \
  --type=merge -p '{"data":{}}'  # don't do this without understanding it
```

### PVC retained but old release name
**Symptom.** Reinstalling with same release name — old PVCs from previous install have data.

**Decision required.** PVCs marked `helm.sh/resource-policy: keep` (Postgres, MinIO, Trino coordinator, metadata-service) survive uninstall. New install reuses them. If you wanted a clean install, delete the PVCs first:
```bash
kubectl -n $NS get pvc
kubectl -n $NS delete pvc <name>  # destroys data
```

## Always do before an upgrade

```bash
# Snapshot release metadata
helm get values $RELEASE -n $NS > backup-values-$(date +%F).yaml
helm get manifest $RELEASE -n $NS > backup-manifest-$(date +%F).yaml

# Diff the upcoming change (requires helm-diff plugin)
helm diff upgrade $RELEASE chart/ -n $NS
```
