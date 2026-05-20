# PostgreSQL (and MariaDB)

## PostgreSQL — primary metadata store

Two Bitnami Postgres releases ship in this chart:

- `postgresql` — Studio metadata, Permify, Temporal databases, pgvector, optionally Hive metastore.
- `postgresqlbigtable` — separate instance for high-volume "bigtable buffer" data.

Both are **Bitnami chart 13.4.4** running `bitnamilegacy/postgresql`. Both have `extendedConfiguration: idle_session_timeout=600000, max_connections=1000` and a `4Gi` PVC.

## Databases inside the primary Postgres

Created by the chart-managed initdb scripts (`peaka.postgresql.initScripts` in `_helpers.tpl`):

| DB / schema | Created by | Used by |
|---|---|---|
| `code2db` | Bitnami init (from `postgresql.auth.database`) | Studio metadata |
| `code2db.studio` (schema) | initdb script | All backend services |
| `code2db.abstract_schema_mapper` (schema) | initdb script (~1300 lines of SQL) | Multi-tenant clone-schema function |
| `permify` | initdb script | Permify |
| `peaka_temporal` | Temporal's `temporal-sql-tool` Job | Temporal default store |
| `peaka_temporal_visibility` | Temporal's `temporal-sql-tool` Job | Temporal visibility store |
| `peaka_s3_metastore` | initdb (only if `metastoreType=postgres`) | Hive Metastore |
| `vectordb` | pgvector init container (`config-init.yaml`) | pgvector |

## The `abstract_schema_mapper` SQL dump

`_helpers.tpl` includes a verbatim Postgres SQL dump of the `abstract_schema_mapper` schema, including the `clone_schema()` PL/pgSQL function (~1000 lines). This implements **multi-tenant per-app schema isolation** — when a customer creates a Peaka "app", a new schema is cloned from a template.

This is one of the more critical pieces of code in the chart. It's also gnarly raw SQL with all the embedded comments from `pg_dump` left in. Don't refactor unless you fully understand what tenant isolation depends on.

## Connection access

Direct from any backend service: `<release>-postgresql.<ns>.svc.cluster.local:5432`.

For Permify only: through PgCat at `<release>-pgcat:6432` (see [pgcat.md](pgcat.md) and ADR-005).

Default credentials: `code2db` / `code2db` (postgres user) and `postgres` / `postgres` (superuser). **Production deployments must override.**

## MariaDB-Galera

- Bitnami chart `11.2.3`, `bitnamilegacy/mariadb-galera:10.11.4`.
- `replicaCount: 1` — Galera is a multi-master replication system, but we run a single node. The Galera bits are mostly inert.
- Sole purpose: **default Hive Metastore backend**.
- 4Gi PVC. Default creds: `peaka` / `peaka`, root `peaka`.

You can swap to Postgres by setting `hiveMetastore.metastoreType: postgres` and `mariadb.enabled: false`. Validation template enforces consistency.

## Files

- Subchart values: `chart/values.yaml#postgresql`, `#postgresqlbigtable`, `#mariadb`
- Init scripts: `chart/templates/postgresql-initdb-scripts.yaml` + `_helpers.tpl#peaka.postgresql.initScripts`
- Helpers: `_helpers.tpl#peaka.postgresql.host`, `peaka.bigtable.*`, `peaka.metastore.*`

## Pitfalls

- `postgresql.auth.postgresPassword: postgres` is the default. **Change it.** This is the superuser password.
- The `bitnamilegacy/*` registry exists because Bitnami split their primary registry. These tags will keep working but won't get new builds — migration should happen eventually.
- 4Gi default PVC is small. Customers running real workloads will fill this and the Postgres pod will crash with `PANIC: could not write to file "pg_wal/..."`. Ship a runbook for resizing.
- When `externalPostgresql.enabled=true`, `postgresql.enabled` must be `false` — validation enforces this.
