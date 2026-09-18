# Architectural Decision Records

These are inferred from code, commit history, and structural choices. Confirm with the maintainer before treating any of them as binding.

## ADR-001 — Single umbrella chart instead of per-service charts

**Decision.** All ~25 Peaka services and 9 stateful dependencies live in one Helm chart (`peaka`).

**Why (likely).** On-prem customers want **one install command, one upgrade command**. Per-service charts would require GitOps tooling (Argo, Flux) the customer may not have. A single chart also keeps inter-service version compatibility tractable: shipping `1.0.11` ships a tested combination.

**Trade-offs.** Long render times. Hard to upgrade a single service in isolation — a hotfix to `be-studio-api` requires bumping the whole chart. The values file is ~2150 lines.

## ADR-002 — Pin all image tags in `values.yaml`, no auto-bump

**Decision.** Every Peaka service has its image tag literally pinned (`be-studio-api:v0.0.349`, `fe-studio-app:v1.1.159-onprem`, ...). Image bumps are committed by hand (`Update image versions` is the most frequent commit message).

**Why.** On-prem releases are versioned, signed, and shipped to customers — *the chart version must reflect a known-good image set.* Auto-bump (e.g., Renovate) would break that contract.

**Trade-offs.** Tedious. Drift between staging-image-bump and an actual chart release is invisible until `helm upgrade`. Consider a script (see [`recommendations.md`](recommendations.md)).

## ADR-003 — Traefik as the only ingress, with `IngressRoute` CRDs

**Decision.** No NGINX/HAProxy/cloud-LB ingress. Traefik handles everything.

**Why.** Need TCP routing for the JDBC port (`dbc`) — vanilla `Ingress` doesn't do TCP. Need `forwardAuth` middlewares to inject `X-Trino-Extra-Credential` headers on JDBC requests. Both are first-class in Traefik. Bonus: a single TLS-termination story.

**Trade-offs.** Customers with an existing NGINX ingress controller still need to install Traefik (or wire their NGINX in front of it). The optional `ingress.enabled` knob exists for this — it adds a vanilla `Ingress` *in front of* Traefik, treating Traefik as a backend `ClusterIP`.

## ADR-004 — Separate Postgres instances for primary metadata vs "bigtable"

**Decision.** Two distinct Postgres releases — `postgresql` and `postgresqlbigtable` (alias) — both Bitnami 13.4.4. Same init scripts.

**Why.** Likely workload isolation: bigtable buffer is high write volume and shouldn't interfere with Studio metadata IOPS. Also lets ops scale them independently in the future.

**Trade-offs.** Two backups, two restore stories, two failure modes. No connection pooler in front of `postgresqlbigtable` (PgCat is only used for Permify).

## ADR-005 — PgCat (PostgreSQL connection pooler) only for Permify

**Decision.** PgCat is deployed and used **only** in the Permify connection URI. Every other Peaka service connects directly to Postgres.

**Why.** The Permify URI sets `plan_cache_mode=force_custom_plan&default_query_exec_mode=cache_describe` — Permify generates many parameterized queries with poor plan-cache behavior, so they route through PgCat in `session` pool mode and inject these libpq settings. Other services don't need this.

**Trade-offs.** Half-finished pattern. If Postgres connection counts ever become a problem for the rest of the platform (currently `max_connections = 1000`), routing everything through PgCat is the obvious next step but isn't free.

## ADR-006 — Hive metastore is a StatefulSet; `metadata-service` keeps a PVC

**Decision.** Hive metastore runs as a StatefulSet (single replica). `be-metadata-service` is a Deployment but mounts a `2Gi` PVC.

**Why.** Hive needs stable network identity for Trino to connect to. `metadata-service` caches connector metadata on disk to avoid re-fetching on every restart.

**Trade-offs.** A Deployment with a single PVC (`metadata-service`) is fragile — `RollingUpdate` strategy on a `ReadWriteOnce` PVC will deadlock during upgrades. Should be a StatefulSet. See [`recommendations.md`](recommendations.md).

## ADR-007 — Hive metastore default backend is MariaDB-Galera, not Postgres

**Decision.** `hiveMetastore.metastoreType: mysql` is the default; the Postgres path exists but is opt-in.

**Why.** Hive's reference implementations are MySQL-centric — Postgres support was added later (commit `de11cac`, "Add postgresql support on metastore"). MariaDB Galera is the most battle-tested deployment.

**Trade-offs.** Customers who don't want a separate database engine for one component end up running both Postgres *and* MariaDB. The chart guards this with `_validation.tpl#peaka.validate.metastore`.

## ADR-008 — Custom CA injection via init containers

**Decision.** When `global.customCACertificates` is set, every backend service gets an init container that imports each cert into the Java truststore (`/truststore/cacerts`) or concatenates them into a Node CA bundle. Then `JAVA_TOOL_OPTIONS` / `NODE_EXTRA_CA_CERTS` are set in the env ConfigMap.

**Why.** On-prem customers terminate TLS at their own ingress with internal CAs. Talking to MinIO/Postgres/MongoDB over TLS requires those CAs to be trusted by every JVM and Node runtime. Doing this once per pod via a shared init-container template is cheaper than baking custom images.

**Trade-offs.** Init container runs `keytool` from the *service's own* image — every Peaka image must therefore bundle a JDK or Node toolchain. Adds ~5–10s to pod startup. The April 2026 commit run (`66c35b6`, `9cdc079`, `b263c03`) shows this was painful to get right.

## ADR-009 — Cert-manager dependency dropped (March 2026)

**Decision.** Removed `cert-manager` requirement (commit `ab3fced`). TLS now uses either an existing K8s Secret (`tls.secretName`) or inline cert/key in values.

**Why.** Customers couldn't always install cluster-scoped CRDs. A simpler "give me a Secret name" flow works in air-gapped clusters too.

**Trade-offs.** No automatic cert renewal — the operator must rotate manually.

## ADR-010 — JWT keypair hard-coded in `_helpers.tpl`

**Decision.** The RSA key used to sign internal JWTs is **base64-embedded in the helpers template** (`peaka.jwt.publicKey` / `peaka.jwt.privateKey`).

**Why.** Default-out-of-the-box install must work without the operator generating keys. Shared keypair across services means any backend can verify any token.

**Trade-offs.** **Every Peaka deployment in the world shares this key** unless someone overrides it. Tracked under [security.md](../questions/security.md) as a critical risk.

## ADR-011 — Express worker as the only StatefulSet backend service

**Decision.** `be-workflow-worker-express` runs as a StatefulSet; every other backend is a Deployment.

**Why.** Likely needs stable pod identity for Temporal sticky-task-queue routing or for resuming long-running activities after pod restart.

**Trade-offs.** Forgettable — every other service is Deployment, so on-call engineers may miss this. Confirm with maintainer.

## ADR-012 — `release-state` service for self-introspection

**Decision.** A small Spring Boot service (`be-release-state`) runs with its own ServiceAccount + Role to `get/list deployments,statefulsets`. It exposes the Helm release name/version and live workload status to Studio.

**Why.** On-prem operators need a "Hello, you're running version X and 3 pods are crashing" health view inside Studio without giving Studio cluster-wide credentials.

**Trade-offs.** Adds a Role/RoleBinding the operator must accept. Fails closed if RBAC is wrong.

## ADR-013 — Drone CI with HMAC-signed pipeline

**Decision.** `.drone.yml` ends with `kind: signature, hmac: <hash>`. Editing the file without re-signing fails CI.

**Why.** Tamper-evidence on the release pipeline (the chart pushes to a public GCS bucket on tag).

**Trade-offs.** Every legitimate `.drone.yml` change needs a paired signature update — see commits `5531c25`, `d1c91ac` ("Update drone signature"). The maintainer needs the HMAC secret to sign locally.
