# Recommendations

Prioritised. "P0" = bite first; "P3" = nice-to-have.

## P0 — Reduce hand-rolled toil

### Automate image-tag bumps
**Problem.** "Update image versions" is the most common commit (~20 in 5 months). Manual editing of `values.yaml` is error-prone and nobody verifies the new tags exist in the registry until `helm install` fails.

**Fix.** A `scripts/bump-images.sh` that takes a manifest like `be-studio-api=v0.0.350` and `yq`-edits `values.yaml`, then runs `helm template . > /dev/null` to validate. Even better: wire **Renovate** with a custom regex manager pointed at `image.tag:` lines (renovatebot.com/docs/regex-manager-presets). Have it open PRs labelled `chart-only`.

**Pros.** Eliminates a class of typos (`v0.0.349` → `v0.0.394`). Tracks new image releases without prompting.
**Cons.** Renovate config is yet another moving piece. Pin Renovate to a digest if you don't trust auto-update of the bot itself.

### Add a `helm lint && helm template` pre-commit hook + CI step
**Problem.** Several recent fixes (`Add missing semi-colon`, `Fix nindent issue on tolerations call`, `Fix slash appearing when tls is false`, `Fix boolean interpretation`) are template-rendering bugs that would have been caught by `helm template`. The Drone pipeline only runs on tag, so dev branches go untested.

**Fix.** Add a Drone step on `event: push` that runs `helm dependency build && helm template . -f tests/values-min.yaml -f tests/values-tls.yaml -f tests/values-ext-pg.yaml`. Three test value files cover: minimal, TLS-on, externalPostgresql. Also add `pre-commit` config locally.

**Pros.** Catches 80% of regressions instantly.
**Cons.** Subchart deps must be pulled in CI (slow without caching).

### Generate `values.schema.json`
**Problem.** Two-thousand-line `values.yaml` with no schema. Customers misformat values regularly. You'd see `tls.enabled: "true"` (string) silently break things — see commit `8daa37e` "Fix boolean interpretation of string value".

**Fix.** Use `helm schema-gen` or [`helm-values-schema-json`](https://github.com/losisin/helm-values-schema-json) on every PR. Helm 3 will validate values against `values.schema.json` automatically.

**Pros.** Operator gets a clear error before chart install runs.
**Cons.** Initial scaffolding takes effort; don't over-constrain (leave room for upstream subchart values).

## P1 — Architectural / operational

### Add resource requests/limits in `values.yaml`
**Problem.** Almost every service has `resources: {}` (empty). On a busy cluster, the K8s scheduler binpacks badly and OOMKills are silent. Trino is the only well-tuned component (25G/50G heaps).

**Fix.** Profile staging, then set conservative defaults per-service. Customers can override.

**Pros.** Predictable scheduling, prevents one bad pod from starving the node.
**Cons.** Wrong defaults break under-provisioned clusters — document the floor.

### `metadata-service` should be a StatefulSet
See ADR-006. It has a `ReadWriteOnce` PVC + Deployment with `RollingUpdate`. Upgrades will deadlock the moment two replicas exist. Convert to StatefulSet.

### Add PodDisruptionBudgets for critical services
**Fix.** PDB with `minAvailable: 1` for: Studio API, Auth, Permission, Token, Dispatcher, Trino coordinator, Hive metastore, Postgres, Temporal frontend. Customers running `kubectl drain` for node maintenance will appreciate it. Several services have empty `podDisruptionBudget: {}` in values — wire them up.

### NetworkPolicy by default
The chart has no NetworkPolicies. On-prem clusters often run with cluster-mesh policies the operator wrote. Adding a deny-all-by-default with explicit allows would be a real security upgrade — but it's invasive enough that I'd talk to the maintainer first.

## P2 — Cleanup

### Split `_helpers.tpl` (currently 2826 lines)

It mixes naming helpers (~200 lines), env vars (~150 lines), the JWT keys (~10 lines, but should be a Secret created externally), Postgres init scripts (~1300 lines of verbatim SQL dump), connector OAuth glue (~300 lines), and Temporal compatibility shims.

Split into:
- `_naming.tpl` — fullname/labels/selector helpers
- `_envvars.tpl` — `peaka.common.envVars`
- `_dependencies.tpl` — host/port/auth helpers per dep
- `_temporal.tpl` — temporal-specific (it's the bulk of the chaos)
- `_initdb-postgres.sql.tpl` — the SQL dump (consider moving to a `files/` directory and using `.Files.Get`)

**Pros.** Easier to navigate, lower cognitive load, smaller diffs.
**Cons.** PR diff is huge; do it once, all in one go.

### Move `peaka.jwt.publicKey` / `peaka.jwt.privateKey` to a generated Secret
See [`security.md`](../questions/security.md). The keys should be generated at install time (`helm install --set jwt.generate=true`) into a Secret with `helm.sh/resource-policy: keep`. Document the rotation procedure.

### Document or remove the `_worker.yaml` filename oddity
`chart/templates/trino/deployment-_worker.yaml` — leading underscore makes Helm skip it. Either rename or confirm it's intentional dead code.

### Set `bitnami` images via tag pinning that doesn't include `legacy`
You're using `bitnamilegacy/postgresql`, `bitnamilegacy/mongodb`, `bitnamilegacy/redis`, etc. The `legacy` track is explicitly second-class — Bitnami's primary registry moved. Migrate when convenient.

## P3 — Nice-to-have

### Replace Drone with GitHub Actions or GitLab CI
Drone is on a slow upstream cadence and not many people run it now. The pipeline is small (5 steps). Migrating to GitHub Actions buys ecosystem maturity, simpler signed-pipeline alternatives, and one less bespoke thing.

### Helm tests
`helm test` hooks for: "can the dispatcher reach the database?", "does Trino respond to a `/v1/info` ping?", "does Temporal frontend respond on gRPC port?" — these would catch most install bugs before the operator does.

### Shrink `temporal.*` value surface
Override unused subkeys with `null` in `values.yaml` (`cassandra: null`, `elasticsearch: null`, `mysql: null`, `prometheus: null`, `grafana: null`). Drops ~150 lines of confusing config.

### `helm-docs` for auto-generated docs
Annotate `values.yaml` with `# @param` comments and run [`helm-docs`](https://github.com/norwoodj/helm-docs) in CI. Generates a `chart/README.md` reference table from comments — saves rewriting docs by hand.

### A staging environment that mirrors customer deployments
The fact that "Update image versions" + "Release chart" + customer hotfix all happen in `main` suggests there's no rolling staging. A nightly `helm install` of the latest chart against test infra would have caught the April 8 "Disable TLS by default in temporal store" hotfix before it shipped.

## Out of scope but worth knowing

- **GitOps adoption** (Argo CD or Flux) is a big lift but solves the "release chart, then customer upgrades when?" gap. Not for this team to push — the customers own their cluster.
- **Operator pattern** — replace the `release-state` service + a future "config update" service with a proper Kubernetes operator (Operator SDK). Probably overkill for a 25-service install today.
