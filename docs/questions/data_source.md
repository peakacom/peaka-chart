# Data sources

There is **no Terraform** in this repo. All persistent state lives inside the Kubernetes cluster, provisioned via Helm subcharts using PVCs. The "infrastructure as code" here is **Helm values**, not Terraform modules.

If the team's other repos use Terraform to provision the *cluster itself* (GKE, EKS, on-prem K8s), that's separate from this chart — ask the maintainer.

## What datastores exist and why

### Primary metadata: PostgreSQL

- **Subchart:** `bitnami/postgresql 13.4.4`, image `bitnamilegacy/postgresql`.
- **Where defined:** `chart/Chart.yaml` (subchart dep) + `chart/values.yaml#postgresql` (config) + `chart/templates/postgresql-initdb-scripts.yaml` (init scripts).
- **What's in it:**
  - DB `code2db` — Studio metadata, app definitions, users.
  - DB `permify` — Permify authorization data.
  - DB `peaka_temporal` — Temporal default store.
  - DB `peaka_temporal_visibility` — Temporal visibility/search store.
  - DB `peaka_s3_metastore` — Hive metastore (only when `metastoreType=postgres`).
  - DB `vectordb` — wait, no — that one's the separate `pgvector` instance.
- **Init scripts** are mounted via the Bitnami chart's `initdb.scriptsConfigMap` mechanism. The ConfigMap content is rendered from `_helpers.tpl#peaka.postgresql.initScripts` — it includes the ~1000-line `abstract_schema_mapper` schema dump (multi-tenancy machinery).
- **PVC:** 4Gi default, **does not have** `helm.sh/resource-policy: keep` — uninstall destroys it. Customers should snapshot/back-up before any chart re-install.

### "Bigtable buffer": PostgreSQL (second instance)

- **Subchart:** same `postgresql` chart, **aliased** as `postgresqlbigtable`.
- **Why two Postgres clusters:** workload isolation. High-write buffer data shouldn't compete with metadata IOPS.
- **Init scripts:** same `peaka.postgresql.initScripts` template — yes, also creates the multi-tenancy schema. (Possibly excessive; verify with maintainer whether bigtable actually needs that.)
- **Helper:** `peaka.bigtable.host`, `peaka.bigtable.port`, etc. in `_helpers.tpl`.

### Connection pooler: PgCat

- **Local template:** `chart/templates/pgcat/`.
- **Used by Permify only.** Other services bypass it.
- See [pgcat technology overview](../architecture/technologies/pgcat.md) and [ADR-005](../architecture/adrs.md).

### Document store: MongoDB

- **Subchart:** `bitnami/mongodb 14.8.0`, `bitnamilegacy/mongodb`.
- **Used by:** `be-collab-sharedb` exclusively (ShareDB OT data).
- **Standalone, no auth** by default.
- **Connection URL** is built by `peaka.mongodb.url` helper — supports inline `connection_uri:` override, `mongodb+srv://`, additional query params. See [mongodb tech overview](../architecture/technologies/mongodb.md).

### Object storage: MinIO (or external S3)

- **Subchart:** upstream `minio ~5.1.0` (not Bitnami).
- **Standalone**, 4Gi PVC with `helm.sh/resource-policy: keep`.
- **Used by:** Trino + Hive metastore (Iceberg data files), connector blob storage.
- **External S3 path:** set `externalObjectStore.enabled: true` and `minio.enabled: false`. Validation enforces XOR.

### Hive metastore backend: MariaDB-Galera

- **Subchart:** `bitnami/mariadb-galera 11.2.3`, **aliased** to `mariadb`.
- **Single replica** (Galera-bootstrap is mostly inert).
- **Sole purpose:** Hive metastore database (when `metastoreType=mysql`, the default).
- **Could be Postgres instead** — controlled by `hiveMetastore.metastoreType: postgres` and toggling `mariadb.enabled: false`.

### Cache: Redis

- **Subchart:** `bitnami/redis 18.11.1`.
- **Standalone, no auth**, NetworkPolicy disabled (commit `d7907fe`).
- Used as a generic cache by various backend services.

### Event bus: Kafka

- **Subchart:** `bitnami/kafka 26.8.5`, KRaft mode.
- 1 controller, PLAINTEXT, 12-hour retention.
- Bootstrap address is exposed as `BOOTSTRAP_ADDRESS` in shared env ConfigMap.

### Vector DB: pgvector

- **Local template:** `chart/templates/pgvector/`. Image `ankane/pgvector:v0.5.1`.
- StatefulSet, separate from the main Postgres cluster.
- DB `vectordb`, schema `studio`. Used by Peaka's AI features.

### Temporal stores
- Run inside the primary PostgreSQL (`peaka_temporal`, `peaka_temporal_visibility`).
- Schema migrations done by `temporal-sql-tool` Job at install/upgrade.
- See [temporal tech overview](../architecture/technologies/temporal.md).

## External vs internal toggles

The chart has matching pairs to swap each datastore for an external one:

| Internal flag | External flag |
|---|---|
| `postgresql.enabled` | `externalPostgresql.enabled` |
| `mongodb.enabled` | `externalMongoDB.enabled` |
| `minio.enabled` | `externalObjectStore.enabled` |

Each pair is XOR-validated by `_validation.tpl`. There is **no externalKafka, externalRedis, or externalMariaDB** — those subcharts cannot be swapped for external services without code changes.

## Where Terraform *could* live (for context)

If the team needs Terraform for **provisioning the K8s cluster + cloud resources around it**, that would normally be:

- A separate repo (e.g., `peaka-infra-terraform`)
- Modules for: GKE/EKS cluster, networking, IAM, GCS bucket for chart distribution, Artifact Registry, Drone runner setup.

This chart repo is **inside that imaginary cluster** — it's the application-layer install. Don't be surprised when there's no `*.tf` here.

## Suggested follow-up

Ask the maintainer:
- "Is there a Terraform repo for the cluster / CI infrastructure I should also know about?"
- "Are there managed databases (Cloud SQL, Atlas) we recommend for production?"
- "Has any customer migrated from internal Postgres to external Postgres mid-flight? What was the procedure?"
