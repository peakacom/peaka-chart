# Trino issues

## Coordinator OOM

**Symptom.** Coordinator pod restarts with exit code 137 or 1; logs show "Java heap space".

**Default heap.** `25G` — may be too low for big plans on busy installs.

**Fix.**
```yaml
trino:
  coordinator:
    jvm:
      maxHeapSize: 50G        # bump
    config:
      query:
        maxMemoryPerNode: 18GB
```

Also consider the cluster-wide cap: `trino.server.config.query.maxMemory=20GB`.

## Worker pods getting killed
**Cause.** Worker heap (50G) > pod memory limit (default unbounded → uses node memory). On a multi-tenant node, the OOM-killer wins.

**Fix.** Set explicit `resources.limits.memory` higher than `maxHeapSize`. Rule of thumb: limit = heap × 1.4.

## Slow queries / queue buildup
```bash
# Trino's web UI on the coordinator is the best diagnostic.
kubectl -n $NS port-forward svc/<release>-trino 8080:8080
# Open http://localhost:8080 — login as 'trino'
```

Look at:
- Active queries tab — long-running ones
- Cluster overview — worker count, splits queued
- Memory usage per query

## Catalog not visible
**Symptom.** `SHOW CATALOGS` doesn't include an expected one.

**Cause.** Catalog config is **dynamic** (`catalog.management=DYNAMIC`). The Peaka services manage catalogs at runtime via Trino's REST API. If a Peaka catalog is missing, the issue is upstream of Trino.

**Check.**
```bash
kubectl -n $NS exec deploy/<release>-trino-coordinator -- \
  curl -s http://localhost:8080/v1/catalog
```

Static catalogs (the ones in the chart) live in `chart/templates/trino/configmap-catalog.yaml`.

## Hive metastore connection failures
**Symptom.** Trino logs `MetaException: Could not connect to meta store using any of the URIs provided`.

**Check.**
```bash
kubectl -n $NS get pod -l app.kubernetes.io/name=<release>-hive-metastore
kubectl -n $NS logs <release>-hive-metastore-0 | tail -30
```

**Common causes.** MariaDB/Postgres backend down, custom CA missing for MinIO connection, wrong access keys.

## TLS to MinIO failing
See [tls-cert-issues.md](tls-cert-issues.md). Trino has its own truststore at `/truststore/cacerts` populated by the same init-container pattern as other backends.

## Useful queries

```sql
-- Currently running queries
SELECT query_id, state, user, query FROM system.runtime.queries
WHERE state = 'RUNNING' ORDER BY created;

-- Memory per query
SELECT query_id, total_memory_reservation, peak_total_memory_reservation
FROM system.runtime.queries WHERE state = 'RUNNING'
ORDER BY total_memory_reservation DESC;
```
