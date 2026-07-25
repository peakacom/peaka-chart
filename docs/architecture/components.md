# Components

The chart deploys ~25 Peaka microservices plus 9 stateful subchart dependencies, fronted by Traefik. Everything ships in a single release; `helm upgrade` updates the whole platform atomically.

## Service categories

### 1. Edge / routing

| Component | Kind | Image | Notes |
|---|---|---|---|
| **Traefik** | subchart | `traefik` 28.2.0 | Sole north-south ingress. Exposes 3 entrypoints: `web` (8000→80), `websecure` (8443→443), `dbc` (4567 — the JDBC port). All routing uses Traefik `IngressRoute` CRDs (not vanilla `Ingress`). |
| **Studio Web** (`fe-studio-app`) | Deployment | `fe-studio-app:v1.1.159-onprem` | Static SPA served by **nginx** on port 8080. Catches all `/` traffic. |

### 2. API/Backend services (Spring Boot / Java)

These all use port 8080 (HTTP) and 9090 (`/actuator/health` for probes). Each has a 1:1 Deployment + ClusterIP Service.

| Service | Image | Role |
|---|---|---|
| `be-studio-api` | `be-studio-api:v0.0.349` | Main backend for Studio. Has a `data-migrator` initContainer that runs DB migrations on every pod start. |
| `be-auth-service` | `be-auth-service:v0.0.21` | Authentication. Validates JWTs signed with the chart-baked RSA keys. |
| `be-token-service` | `be-token-service:v0.0.84` | OAuth callback handler at `/oauth2/callback`. |
| `be-permission-service` | `be-permission-service:v0.0.66` | Authorization. Talks to **Permify** (subchart). Also serves the `forwardAuth` endpoint for the JDBC ingress. |
| `be-runtime-api` | `be-runtime-api:v0.0.20` | Connector runtime metadata. |
| `be-metadata-service` | `be-metadata-service:v0.0.26` | Metadata API. Has its own PVC (`metadataService.persistence`) — **stateful Deployment** (see ADR-006). |
| `be-data-rest` | `be-data-rest:v1.0.4` | JDBC bridge. Behind the `dbc` entrypoint — converts HTTP→Trino. |
| `be-data-cache` | `be-data-cache:v0.0.148` | Materialized-view query layer. Has a `flow-utilities` sidecar (JEXL evaluator on `localhost:8080`). |
| `be-search-service` | `be-search-service:v0.1.122-onprem.1` | Full-text search. Optional Bull dashboard (`bullDashboardEnabled`). |
| `be-secret-store-service` | `be-secret-store-service:v0.0.20` | Encrypted secret storage. AES key in `secretStoreService.secretEncryptionKey`. |
| `be-monitoring-service` | `be-monitoring-service:v0.0.50` | App-level metrics/usage tracking. |
| `be-email-service` | `be-email-service:v0.0.12` | SMTP/SendGrid wrapper. |
| `be-cloud-gateway` | `be-cloud-gateway:v1.0.8` | Outbound proxy for connector calls. |
| `be-webhook-resolver` | `be-webhook-resolver:v0.0.35` | Inbound webhook handler. |
| `be-collab-sharedb` | `be-collab-sharedb:v0.0.21` | Realtime collaboration backend. **Two services** (HTTP + WebSocket) for the same pod. Stores in MongoDB. |
| `be-sql-service` | `be-sql-service:v0.0.2` | SQL-as-a-service adapter. Newest service — minimal config. |
| `be-release-state` | `be-release-state:v1.0.1` | **Reflects the install state back to Studio.** Has its own ServiceAccount with `get/list` on Deployments+StatefulSets so the UI can show what's healthy. |

### 3. Workflow / queue plane

| Service | Image | Role |
|---|---|---|
| **Temporal** | subchart (Cassandra-style values, but SQL-backed) | Workflow engine. 4 services: frontend, history, matching, worker. Backed by `postgresql` (default & visibility stores in DBs `peaka_temporal` / `peaka_temporal_visibility`). Schema setup runs as a **Helm post-install/post-upgrade Job**. |
| `be-workflow-starter` | `be-workflow-starter:v0.0.98` | Submits workflows to Temporal. |
| `be-workflow-history` | `be-workflow-history:v0.0.24` | History queries / replay. |
| `be-workflow-worker-express` | `be-workflow-worker-express:v0.0.98` | Express-based action executor. **StatefulSet** (the only express service that is). Has `flow-utilities` sidecar. |
| `be-scheduled-flow-runner` | `be-scheduled-flow-runner:v0.0.11` | Cron-style scheduler. |
| `be-dispatcher` | `be-dispatcher:v0.0.27` | API gateway behind `/api`. Routes to backend services. |
| `be-dispatcher-assigner` | `be-dispatcher-assigner:v0.0.13` | Sticky-session assigner. |
| `be-dispatcher-dlq` | `be-dispatcher-dlq:v0.0.14` | Dead-letter handler. |

### 4. Data / storage plane

| Component | Kind | Image / version | Role |
|---|---|---|---|
| **PostgreSQL** (`postgresql`) | subchart `13.4.4` (Bitnami) | `bitnamilegacy/postgresql` | Primary metadata store. Holds: `code2db` (Studio DB), `permify`, `peaka_temporal`, `peaka_temporal_visibility`, `peaka_s3_metastore` (when metastore=postgres). InitContainer scripts create databases + the `abstract_schema_mapper` schema. 4Gi PVC. |
| **PostgreSQL big-table** (`postgresqlbigtable`) | subchart `13.4.4` (alias) | same | Separate Postgres instance for high-volume "bigtable buffer" data. Same init scripts. |
| **PgCat** | local template | `ghcr.io/postgresml/pgcat:v1.2.0` | PostgreSQL connection pooler (port 6432). Sits in front of `postgresql` for **Permify only** today. |
| **MongoDB** | subchart `14.8.0` (Bitnami) | `bitnamilegacy/mongodb` | Used by `collab-sharedb`. Standalone, no auth by default. |
| **Redis** | subchart `18.11.1` (Bitnami) | `bitnamilegacy/redis` | Cache. Standalone, no auth. NetworkPolicy disabled. |
| **Kafka** | subchart `26.8.5` (Bitnami) | `bitnamilegacy/kafka` | KRaft mode (no ZK). PLAINTEXT. 20 partitions, 12h retention, 50MB max msg. |
| **MinIO** | subchart `~5.1.0` | upstream | S3-compatible object store. Standalone, 4Gi. Default creds `console`/`console123`. |
| **MariaDB Galera** (`mariadb`) | subchart `11.2.3` (alias) | `bitnamilegacy/mariadb-galera:10.11.4` | Default Hive metastore backend. 1 replica (galera misnomer). |
| **Hive Metastore** | local StatefulSet | `hive-metastore:v1.0.4` (private) | Iceberg metadata service on port 9083. Stores in MariaDB or Postgres. Connects to MinIO/S3. |
| **Trino** | local | `trino:v1.0.4-onprem.1` (private fork) | Query engine. Coordinator (Deployment + 1Gi PVC) + worker (Deployment, optional HPA). 25G/50G heap. Reads from Hive metastore + Iceberg + MinIO. Has Peaka access-control plugin. |
| **Permify** | subchart `0.4.0` | `permify:v1.3.6` | Authorization (Zanzibar-style). Postgres-backed. |
| **pgvector** | local StatefulSet | `ankane/pgvector:v0.5.1` | Vector DB for AI features. Schema `studio` in DB `vectordb`. |

### 5. Streaming / change-data-capture

| Component | Image | Role |
|---|---|---|
| **kafka-connect** | `quay.io/debezium/connect:3.1` | CDC connector runtime. Avro-converted topics. |
| **monitoring-kafka-connect** | `code2io/peaka-kafka-connect:v1.0.1` | Separate Connect cluster for Peaka's monitoring pipelines. JSON converter, larger heap (4G). Has JMX/Prometheus hooks (disabled by default). |

## Cross-cutting templates

These run at chart-root level (not per-service):

| Template | Purpose |
|---|---|
| `env-configmap.yaml` | One ConfigMap with ~80 env vars consumed by every backend service via `envFrom`. Source: `peaka.common.envVars` in `_helpers.tpl`. |
| `connection-credentials-secret.yaml` | OAuth client IDs/secrets for connector providers (Google, HubSpot, Slack, etc.). |
| `image-pull-secret.yaml` | GCR docker-registry secret built from a JSON service-account key supplied by Peaka. |
| `jwt-rsa-secret.yaml` | **Hard-coded** RSA keypair embedded in `_helpers.tpl` (lines 377–383). Used by all services to sign/verify JWTs. See [security.md](../questions/security.md). |
| `tls-secret.yaml` | TLS cert for Traefik's `websecure` entrypoint, when `tls.enabled=true`. |
| `permify-postgresql-uri-secret.yaml` | Permify connects to Postgres **through PgCat**, with `plan_cache_mode=force_custom_plan` set in the URI. |
| `custom-ca-certs.yaml` | ConfigMap of customer-provided CA certs. Each backend service has an init container that imports them into the Java truststore (`-Djavax.net.ssl.trustStore`) or NodeJS bundle (`NODE_EXTRA_CA_CERTS`). |
| `validate.yaml` | Calls four `_validation.tpl` checks at render time — fails `helm install` if `postgresql` and `externalPostgresql` are both enabled (and similar). |
| `postgresql-initdb-scripts.yaml` | The big one — produces a ConfigMap mounted by Bitnami Postgres at first start, containing: DB creates, the `studio` schema, and a 1300-line dump of the `abstract_schema_mapper` schema (multi-tenancy clone-schema function). |

## Service-to-service communication map

All in-cluster traffic uses `<service>.<namespace>.svc.cluster.local`. The pattern is hard-coded in `_helpers.tpl#peaka.common.envVars`. Highlights:

- Every backend reads `MINIO_*`, `DB_*`, `REDIS_*`, `KAFKA_*`, `TEMPORAL_TARGET`, `TRINO_ADDRESS` from the shared ConfigMap.
- `be-data-cache` and `be-workflow-worker-express` run a **JEXL sidecar** on `localhost:8080` (env: `JEXL_ADDRESS`).
- Frontend resolves API endpoints from the same ConfigMap via `STUDIO_API_URL`, `DISPATCHER_URL`, `TOKEN_SERVICE_PUBLIC_URL`. The web app is configured via injected env vars into the `nginx` config — see `studio-web-configmap.yaml`.
- The JDBC path is unique: client → Traefik `dbc:4567` → middleware `forwardAuth` (calls `be-permission-service`) → `be-data-rest` → Trino coordinator over JDBC.
