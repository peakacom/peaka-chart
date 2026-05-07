# Temporal

A workflow orchestration engine. You write workflows as code (in Java/TypeScript/Go), Temporal persists every state transition durably, and replays the workflow on failure. Think "Airflow for transactional, long-running, code-first workflows".

## How this project uses Temporal

- **Four server services** in one StatefulSet-style deployment: `frontend` (gRPC 7233), `history` (7234), `matching` (7235), `worker` (7239). All inside one Helm release.
- **Backed by PostgreSQL** (the same `postgresql` instance used for Studio metadata), but in two separate databases: `peaka_temporal` (default store) + `peaka_temporal_visibility` (visibility store).
- **Schema setup runs as a Helm post-install/post-upgrade Job** (`server-job.yaml`). It uses `temporal-sql-tool` to create + migrate the schema. `backoffLimit: 100` — it'll retry forever if Postgres isn't ready yet.
- **No Cassandra, no Elasticsearch.** The chart inherits values for them but they're disabled. This is a SQL-backed, in-process Temporal cluster.
- **`numHistoryShards: 512`** — fixed at install time. **Cannot be changed** without nuking the database (chart's own warning).

## Peaka services that use Temporal

| Service | Role |
|---|---|
| `be-workflow-starter` | Submits workflows to Temporal frontend |
| `be-workflow-worker-express` | Activity worker (StatefulSet) |
| `be-workflow-history` | Read-side queries on workflow history |
| `be-scheduled-flow-runner` | Cron-style scheduling using Temporal schedules |

The Temporal server's address is exposed to Peaka services as the env var `TEMPORAL_TARGET=<release>-temporal-frontend.<ns>.svc.cluster.local:7233`.

## TLS

- Recently added: `temporal.server.config.persistence.{default,visibility}.sql.tls` block (Apr 7, 2026, commits `8efb268`, `bf41ff8`).
- Default is **off** (commit `b1e9fb2` reverted to off after a customer install broke).
- Enabling requires loading a CA secret as `secretName: postgresql-tls` and mounting it via `additionalVolumes`/`additionalVolumeMounts`.

## Files

- Subchart values: `chart/values.yaml#temporal` (note: this is a **fork** of upstream temporal-helm, not a true subchart dep — it's vendored into the chart's own templates)
- Templates: `chart/templates/temporal/`
- Schema setup Job: `chart/templates/temporal/server-job.yaml`

## Pitfalls

- The values surface for Temporal is *huge* (`temporal.server.frontend.*`, `temporal.server.history.*`, etc., plus disabled subkeys for Cassandra/ES/Prometheus/Grafana — all upstream-compatible noise).
- The schema-setup Job uses `helm.sh/hook-delete-policy: hook-succeeded,hook-failed,before-hook-creation` — it's deleted after success. **You will not see it in `kubectl get jobs` after install.** That's by design.
- If Postgres isn't reachable, the Job loops forever. Check `kubectl logs -l app.kubernetes.io/component=database` during a stuck install.
- If you ever change the Postgres password and run `helm upgrade`, the schema-update Job will fail until the secret reflects the new password.
