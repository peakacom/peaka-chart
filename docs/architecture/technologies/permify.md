# Permify

A Zanzibar-style authorization service (inspired by Google's Zanzibar paper). You define a schema of object-types and relationships ("user X is editor of project Y"), then ask "can user X read project Y?" and Permify checks the relationship graph.

## How this project uses Permify

- Subchart `0.4.0`, image `permify:v1.3.6`.
- Single replica (`replicaCount: 1`).
- Backed by **PostgreSQL via PgCat** — the only Peaka-internal user of PgCat.
- Auto-migrates schema on startup (`auto_migrate: true`).
- Permission cache: 10000 counters / 2048 MiB max cost.

## How Peaka calls it

`be-permission-service` (Spring Boot) is the Peaka-side fronting service. It calls Permify's HTTP API at:

```
http://<release>-permify:<permify.app.server.http.port>
```

(env var: `PERMIFY_URL`). All ACL/authorization checks for the JDBC ingress, Studio API, and runtime go through `be-permission-service` → Permify.

## Postgres connection

Permify connects to Postgres through PgCat with a query string carefully tuned for its access pattern:

```
postgres://<user>:<pass>@<release>-pgcat:6432/permify?sslmode=prefer&plan_cache_mode=force_custom_plan&default_query_exec_mode=cache_describe
```

- `plan_cache_mode=force_custom_plan` prevents Postgres from caching generic query plans (Permify's parameterized queries are slow with cached plans).
- `cache_describe` keeps prepared-statement metadata.
- These were tuned through real performance work — don't remove without measuring.

The URI is rendered into a Secret (`peaka-permify-postgresql-uri-secret`) read by Permify at startup.

## Files

- Subchart values: `chart/values.yaml#permify`
- Secret: `chart/templates/permify-postgresql-uri-secret.yaml`

## Pitfalls

- Permify's schema migrations can be slow on first startup against a busy Postgres. The `auto_migrate: true` setting may time out if Postgres is under load.
- Account ID `recdK3q5xuwJdGjrh` in `values.yaml` is **literally hard-coded**. Looks like an Airtable record ID. Confirm with maintainer whether this is per-deployment or fine to be shared.
- `permify.app.service.circuit_breaker: false` — circuit breaker off. Fine while traffic is low; for HA, consider enabling.
