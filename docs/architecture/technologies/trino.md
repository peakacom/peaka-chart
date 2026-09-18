# Trino + Hive Metastore

**Trino** is a distributed SQL query engine for federated analytics. Reads from many sources (S3/Iceberg, Postgres, Mongo, Kafka, etc.) through "catalogs". This is the **query plane** for Peaka: the value proposition is that customers point Trino at their data and run SQL across all of it.

**Hive Metastore** is the catalog service Trino uses for Iceberg tables (the schema/metadata; data lives in S3/MinIO).

## How this project uses Trino

- **One coordinator + N workers**, both as Deployments. Coordinator has a 1Gi PVC; workers can be HPA-scaled (off by default).
- Heavy JVM tuning (`values.yaml#trino`):
  - Coordinator: `25G` heap, G1GC, byte-manipulation Java agent.
  - Worker: `50G` heap.
  - Both: `query.max-memory=20GB`, `query.max-memory-per-node` 9G/15G.
- **Custom image** `trino:v1.0.4-onprem.1` — Peaka's own fork. Includes the Peaka access-control plugin (`access-control.name=peaka-access-control`).
- `catalog.management=DYNAMIC` — catalogs can be added/removed at runtime via Trino's REST API (no restart). Driven by Peaka's runtime services.
- **Filesystem exchange manager** at `/tmp/trino-local-file-system-exchange-manager` (in-cluster only — fine for non-fault-tolerant workloads).
- Optional Kerberos: `server.kerberosConfig` and `server.kerberosKeytab` for authentication against external Hadoop clusters.

## Trino connection points

- Internal HTTP: `http://<release>-trino:8080`
- JDBC URL (rendered in env): `jdbc:trino://<release>-trino:8080/?user=trino`
- External (operator-facing): JDBC clients hit Traefik `dbc:4567` → `be-data-rest` → Trino.

## Hive Metastore

- StatefulSet, single replica, port `9083` (Thrift).
- Backend: MariaDB-Galera (default) or PostgreSQL (`hiveMetastore.metastoreType: postgres`).
- Connects to MinIO using `minioAccessKey` / `minioSecretKey` (default `console` / `console123`).
- Custom image `hive-metastore:v1.0.4` (Peaka private). The container expects `METASTORE_DB_HOSTNAME`, `METASTORE_TYPE`, etc. in env.

## Catalog config

- `chart/templates/trino/configmap-catalog.yaml` is the Helm-managed catalog file. Contains the static catalogs (Hive/Iceberg pointing at MinIO, Postgres for `code2db`, etc.).
- Customer-defined catalogs are added through the Studio UI (which calls Trino's `catalog.management=DYNAMIC` API).

## Files

- Templates: `chart/templates/trino/`
- Values: `chart/values.yaml#trino`
- Hive: `chart/templates/hive-metastore/`

## Pitfalls

- The `deployment-_worker.yaml` filename starts with `_` — Helm normally skips files starting with `_`. **Verify with `helm template` whether the Trino worker is actually being rendered**. If not, this is a long-standing bug masked by `node-scheduler.include-coordinator=true` (coordinator does worker duty when `workers=0`).
- Coordinator PVC is `1Gi` with `helm.sh/resource-policy: keep`. If you `helm uninstall`, the PVC stays. Customer must manually clean up.
- The custom Java agent `trino-byte-manipulation.jar` is a Peaka-built JAR injected via JVM args. If it goes missing, Trino fails to start.
- Hive metastore + MariaDB metastore type cannot coexist with `mariadb.enabled=false`. The validation template guards this.
