# Obsolete / abandoned code

Things that look unused, half-removed, or leftover from a different era. **Do not delete without checking with the maintainer** — these are *candidates*.

## Removed dependencies (already gone, mentioned for context)

| What | Removed in | Notes |
|---|---|---|
| ClickHouse | `fab177c` (Feb 2026) | Was a chart subdependency. Suggests an analytics direction was abandoned. |
| `application.yaml` static file | `ef5e0e6` (Mar 2026) | 60-line file removed; configuration moved entirely into Helm-rendered ConfigMaps. |
| cert-manager requirement | `ab3fced` (Mar 2026) | See ADR-009. |
| An unnamed helm dependency | `4f870ab` (Apr 2026) | Last release-time cleanup. Maintainer can name it. |

## Code paths that look dead today

### Cassandra / Elasticsearch / Prometheus / Grafana under `temporal.*`

`values.yaml` has a giant `temporal.cassandra.*`, `temporal.elasticsearch.*`, `temporal.prometheus.*`, and `temporal.grafana.*` block (lines 1194–1290). All have `enabled: false`.

These are **upstream Temporal Helm chart values that we copy verbatim**, even though we always run Temporal on Postgres. We don't ship Cassandra. We don't ship Elasticsearch. We don't enable the bundled Prometheus or Grafana. These ~100 lines exist solely to satisfy the original schema.

→ **Suggested action**: keep but document, or override with `null` to shrink the values surface area.

### `temporal.web.enabled: false` (Temporal UI)

The Temporal UI is shipped in the chart (`web-deployment.yaml`, `web-service.yaml`) but disabled by default. If nobody uses it on-prem, it's pure code weight.

### `temporal.admintools.enabled: false`

Same story — ships disabled. If you've never seen anyone exec into `tctl`, the `admintools-deployment.yaml` template is dead weight.

### `temporal.mysql.enabled: false`

Hard-coded `false`. Never been enabled. Branches in `_helpers.tpl#peaka.temporal.persistence.sql.secretName` reference this MySQL path — it's a vestigial limb.

### `kafkaConnect.cp-schema-registry.url: ""` and helpers

Schema registry support exists in helpers (`peaka.kafka-connect.cp-schema-registry.fullname`) but no schema-registry pod is shipped. The URL field is empty by default, and no `monitoring-kafka-connect.kafka.bootstrapServers` is set either. **Tells me** the original design assumed a schema registry that was either dropped or expected from the customer.

### `connector.credentials.provider.*` with no defaults

In `values.yaml`, twelve OAuth providers are listed (`google`, `hubspot`, `slack`, `intercom`, `linkedin`, `dynamics_365`, `quickbooks_online`, ...). All `clientId`/`clientSecret` default to *blank*. The `peaka.connectors.defaultOauthClients` template only emits an entry if both fields are non-empty — meaning out-of-the-box, no providers are configured.

This is fine, but the value-file shape suggests the team imagined operators would fill these. In practice, they likely configure providers inside Studio after install.

### `temporal.serviceAccount.create: false`

Default. Means Temporal pods run with the namespace's `default` SA. Combined with `temporal.web.enabled: false` and `temporal.admintools.enabled: false`, the `serviceaccount.yaml` template under `temporal/` may render zero resources in normal installs.

### `studioWeb.readinessProbe: {}` (and other empty probes)

Several services have `livenessProbe: {}` and `readinessProbe: {}` set as empty maps in `values.yaml`. The deployment templates use `{{- with .resources }}` etc., so empty maps are skipped — but it's dead config that confuses readers.

## Cosmetic / structural debris

### `chart/templates/trino/deployment-_worker.yaml`

The leading underscore (`_worker`) is unusual. In Helm, files starting with `_` are skipped from rendering by convention — but the contents look like a real worker Deployment template. Possibly a bug that never fired because the worker is rendered through *another* mechanism, or a file that was renamed but not cleaned up. **Worth verifying with a `helm template`.**

### `accessControl.type: configmap` branch

`configmap-coordinator.yaml` has logic for two access-control modes: `properties` (the default, used) and `configmap` (loads `rules.json`). The `configmap` branch references values (`accessControl.refreshPeriod`, `accessControl.configFile`) that **do not exist anywhere in `values.yaml`**. So either it was a planned feature, or it's used in a customer-specific override.

### `JEXL_ADDRESS: localhost:8080`

Several services set this even though they don't have a JEXL sidecar. Harmless but misleading.

### `dataMigrator` referenced as init container with `dataMigrator.image.registry`

The `data-migrator` initContainer is used in many deployments, but `dataMigrator` only has `image.{name,tag,imagePullPolicy}` fields in `values.yaml` — `registry` is read but never set. Falls back to global. Not broken, but the partial schema is a tripping hazard.

## Things that *look* unused but are not

- **`postgresqlbigtable`** — at first glance looks like a duplicate Postgres. It is not — it's a separate instance for high-write data (see ADR-004).
- **`monitoring-kafka-connect`** — looks like a duplicate of `kafka-connect`. It is also a separate Connect cluster for Peaka's monitoring pipelines.
- **PgCat** — only used by Permify today, not dead code (see ADR-005).
