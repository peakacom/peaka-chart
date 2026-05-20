# `helm install` is hanging or pods stuck

## Triage in 60 seconds

```bash
NS=peaka
kubectl -n $NS get pods --no-headers | awk '$3!="Running" && $3!="Completed"'
kubectl -n $NS get events --sort-by=.lastTimestamp | tail -30
```

## Most common causes

### 1. ImagePullBackOff
**Symptom.** Pods stuck in `ImagePullBackOff`, `kubectl describe pod` shows `unauthorized: ...`.

**Cause.** `peakaContainerRegistryAccessSecret` not set, or the JSON in `gcpRegistryAuth.password` is malformed.

**Fix.**
```bash
# Verify the secret exists and has the right type
kubectl -n $NS get secret peaka-docker-registry -o jsonpath='{.type}'
# Should print: kubernetes.io/dockerconfigjson

# If it's missing, re-render with the JSON file Peaka gave you:
helm upgrade $RELEASE chart/ -n $NS \
  --set-file peakaContainerRegistryAccessSecret.gcpRegistryAuth.password=./peaka-gcr.json \
  --set peakaContainerRegistryAccessSecret.name=peaka-docker-registry
```

### 2. Postgres init scripts failing
**Symptom.** `<release>-postgresql-0` is `Running` but no other pods make progress; backend pods Pending or CrashLoop with "FATAL: database does not exist".

**Cause.** The postgresql initdb ConfigMap is mounted but the SQL is invalid (rare — would need a recent helper change).

**Fix.**
```bash
kubectl -n $NS logs <release>-postgresql-0 | grep -A3 ERROR
# Reset (DESTRUCTIVE — only if no real data yet):
kubectl -n $NS delete pvc data-<release>-postgresql-0
helm upgrade $RELEASE chart/ -n $NS  # re-runs init
```

### 3. Temporal schema-setup Job stuck
**Symptom.** `kubectl get jobs` shows `<release>-temporal-schema-setup` with backoff. Other Temporal pods CrashLoop.

**Cause.** Postgres not yet reachable when the Job tried to migrate. Or wrong db credentials.

**Fix.**
```bash
kubectl -n $NS logs job/<release>-temporal-schema-setup | tail -50
# Verify Postgres is up:
kubectl -n $NS exec -it <release>-postgresql-0 -- psql -U code2db -c '\l'
# If creds are wrong, rotate (see secrets-rotation.md).
# Otherwise the Job retries up to backoffLimit=100 — usually resolves itself.
```

### 4. PVC pending — no storage class
**Symptom.** `kubectl get pvc` shows `Pending`. `kubectl describe pvc` says "no persistent volumes available".

**Cause.** Cluster has no default StorageClass.

**Fix.** Set `global.storageClass` in values, or set default via:
```bash
kubectl get sc
kubectl annotate sc <name> storageclass.kubernetes.io/is-default-class=true
```

### 5. CRDs missing for Traefik
**Symptom.** `helm install` errors: `no matches for kind "IngressRoute" in version "traefik.io/v1alpha1"`.

**Cause.** Traefik CRDs not installed in cluster.

**Fix.**
```bash
kubectl apply --server-side --force-conflicts -k https://github.com/traefik/traefik-helm-chart/traefik/crds/
```

### 6. Validation failure at render time
**Symptom.** `helm install` exits immediately: `Error: execution error: ... peaka.validate.<X>: ...`.

**Cause.** Mutually-exclusive flags both set or both unset (e.g., `postgresql.enabled` AND `externalPostgresql.enabled` both true).

**Fix.** Read the message; flip one flag. See `chart/templates/_validation.tpl`.

## When `helm install` itself is hanging (not pods)

```bash
helm install ... --debug --timeout 30m
# If post-install hooks are running (Temporal Job), they wait for completion.
# Use --wait=false to skip waiting:
helm install ... --no-hooks  # last resort; install without Temporal schema
```
