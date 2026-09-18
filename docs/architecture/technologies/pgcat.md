# PgCat

A Postgres connection pooler / load balancer written in Rust. Like PgBouncer but with extra features: query parser, read/write splitting, sharding, prometheus metrics.

## How this project uses PgCat

- Image: `ghcr.io/postgresml/pgcat:v1.2.0`. Single replica, port `6432`.
- **Used only by Permify** in the current chart.

The pool config uses `pool_mode: session` with `query_parser_enabled: true` and `query_parser_read_write_splitting: true`. Permify is the sole pool — its name comes from `permify.app.database.name`.

Admin DB credentials: `postgres`/`postgres` (default). Connecting to that "virtual" database lets you run `SHOW POOLS`, `SHOW DATABASES`, etc.

## Why only Permify?

See ADR-005. Permify generates many parameterized queries with poor plan-cache behavior; PgCat in `session` mode + the libpq settings in the URI (`plan_cache_mode=force_custom_plan`) work around that. Other Peaka services don't have this issue, so they connect directly to Postgres.

## Files

- Templates: `chart/templates/pgcat/`
- Values: `chart/values.yaml#pgcat`
- Helpers: `_helpers.tpl#peaka.pgcat.*`

## Pitfalls

- The chart-managed `Secret` rendered by `pgcat/secret.yaml` contains the user/password. Default creds are weak — override.
- Custom CA support added recently — see `pgcat/deployment.yaml` init container that mounts custom CA certs.
- TLS to upstream Postgres is off (`server_tls: false`). If you turn on Postgres TLS, you must also flip this.
- If you add a second Peaka service to PgCat, you must define a **second pool** in `pgcat.configuration.pools` — it's a list, not auto-derived.
