# Active technologies

What's actually load-bearing in this chart, with brief intros and how each fits Peaka's flow.

| Tier | Technology | Role | File |
|---|---|---|---|
| Build | Helm 3 | Chart packaging / install | [helm.md](helm.md) |
| Build | Drone CI | Tag-triggered package + GCS publish | [drone.md](drone.md) |
| Build | GCS bucket as Helm repo | Public chart distribution | [helm.md](helm.md) |
| Routing | Traefik (CRD mode) | Sole north-south ingress + TCP for JDBC | [traefik.md](traefik.md) |
| Compute | Trino | Federated SQL engine — heart of the platform | [trino.md](trino.md) |
| Compute | Temporal | Workflow / activity orchestration | [temporal.md](temporal.md) |
| Compute | Hive Metastore | Iceberg table catalog for Trino | [trino.md](trino.md) |
| Storage | PostgreSQL (Bitnami) | Metadata, Permify, Temporal, vector DB | [postgresql.md](postgresql.md) |
| Storage | MariaDB-Galera (Bitnami) | Default Hive metastore backend | [postgresql.md](postgresql.md) |
| Storage | MongoDB (Bitnami) | Realtime sharedb collaboration data | [mongodb.md](mongodb.md) |
| Storage | MinIO | S3-compatible object store | [minio.md](minio.md) |
| Storage | Redis (Bitnami) | Cache | — (well-known) |
| Streaming | Kafka (KRaft mode) | Event bus | [kafka.md](kafka.md) |
| Streaming | kafka-connect (Debezium) | CDC connectors | [kafka.md](kafka.md) |
| Auth | Permify | Zanzibar-style authorization | [permify.md](permify.md) |
| Auth | PgCat | Postgres pooler (used only by Permify) | [pgcat.md](pgcat.md) |
| AI | pgvector | Vector search for AI features | — (Postgres + extension) |

Skip the file for any tech you already know — these are quick refreshers, not full primers.
