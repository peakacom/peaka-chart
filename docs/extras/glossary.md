# Glossary

Project-specific terms that show up in code, values, or commits.

| Term | Means |
|---|---|
| **App** | Inside Peaka, a "tenant project". Each App has its own schema cloned from a template via `abstract_schema_mapper.clone_schema()`. |
| **Catalog** | Trino term: a connector configuration pointing at a data source. Peaka manages these dynamically (`catalog.management=DYNAMIC`). |
| **Connector** | Peaka's abstraction for a SaaS data integration (Google Ads, HubSpot, Slack…). Configured in `connector.credentials.provider.*`. |
| **DBC** | "Database Connectivity" — Peaka's JDBC port (`dbc:4567`). Confusingly *not* a Java acronym. |
| **Studio** | Peaka's web app (`fe-studio-app`) and API (`be-studio-api`). The user-facing product. |
| **Bigtable** | Local term for the high-write Postgres buffer (`postgresqlbigtable`). Not Google's product. |
| **Sharedb** | Realtime collab using ShareDB (operational transforms, MongoDB-backed). |
| **Onprem** / **on-prem** | This chart's whole purpose. As opposed to Peaka Cloud. |
| **Code2** | Internal codename — appears as `code2db`, `CODE2_DOMAIN`, registry path `code2-324814`. Old Peaka name. |
| **Forward auth** | Traefik middleware that calls a sidecar service to inject auth headers — used for the JDBC ingress. |
| **Express worker** | `be-workflow-worker-express` — Node/Express-based action executor with a JEXL sidecar. |
| **JEXL** | Java Expression Language. Used for evaluating user-supplied expressions in flows. The sidecar binds to `localhost:8080` next to express workers. |
| **Permify** | Zanzibar-style authorization service. Powered by relations + permission rules. |
| **PgCat** | A Rust-based Postgres connection pooler. We use it only for Permify's traffic. |
| **Hive metastore** | Apache Hive's catalog service (Thrift on 9083) — Trino reads it to know which Iceberg tables exist. |
| **Iceberg** | Apache Iceberg table format. Schema lives in Hive metastore; data files live in S3/MinIO. |
| **Bitnami legacy** | The `bitnamilegacy/*` Docker registry — Bitnami's secondary registry. Will keep working but won't get new images. |
| **Drone** | The CI system. Pipelines defined in `.drone.yml`, signed with HMAC. |
| **Bitnami Galera** | A MariaDB Galera cluster from Bitnami. We run a single replica, so the Galera replication isn't actually used. |
| **KRaft** | Kafka's ZooKeeper-less mode (Kafka Raft). The Bitnami chart uses it by default. |
| **`accessUrl`** | The values block describing how the customer accesses Peaka (domain, scheme, ports). Determines URL building in env vars. |
| **`peaka.fullname`** | Helm template producing the release-prefixed name (e.g., `mypeaka-be-studio-api`). |
| **`abstract_schema_mapper`** | The PL/pgSQL schema embedded in `_helpers.tpl` that handles multi-tenant per-app schema cloning. |
