# Temporal issues

## Schema-setup Job failing on install/upgrade

```bash
kubectl -n $NS logs job/<release>-temporal-schema-setup
kubectl -n $NS logs job/<release>-temporal-schema-update     # for upgrades
```

### Cause: Postgres unreachable
Look for `connection refused` / `no host`. Verify Postgres is up:
```bash
kubectl -n $NS exec <release>-postgresql-0 -- pg_isready
```

### Cause: wrong DB name
The chart creates `peaka_temporal` and `peaka_temporal_visibility` automatically *only if* the `temporal-sql-tool` Job runs them. If `temporal.server.config.persistence.default.sql.database` was changed mid-install, the Job will look for the wrong DB.

**Fix.** Set the values back to defaults, or manually create the new DB:
```bash
kubectl -n $NS exec <release>-postgresql-0 -- \
  psql -U postgres -c 'CREATE DATABASE peaka_temporal;'
```

### Cause: wrong password
The Job pulls the password from a Secret. If you rotated the Postgres password without `helm upgrade`, the Job has stale creds.
```bash
helm upgrade $RELEASE chart/ -n $NS  # re-renders Secrets and re-runs the Job
```

## Temporal frontend pod not ready

**Symptom.** `<release>-temporal-frontend` is `Running` but readiness fails. Workflow workers can't connect (`TEMPORAL_TARGET` unreachable).

**Check.**
```bash
kubectl -n $NS exec deploy/<release>-temporal-frontend -- \
  /bin/bash -c 'tcping localhost 7233 || echo NO'
kubectl -n $NS logs deploy/<release>-temporal-frontend | tail -50
```

Common: history service can't connect to its DB → frontend stays not-ready.

## Workflow stuck

```bash
# Get into admintools (if enabled, otherwise port-forward and use tctl from your laptop)
kubectl -n $NS exec -it deploy/<release>-temporal-admintools -- /bin/bash
tctl --address <release>-temporal-frontend:7233 workflow list
tctl workflow describe -w <workflow-id>
```

`temporal.admintools.enabled: false` by default. To enable transiently:
```bash
helm upgrade ... --set temporal.admintools.enabled=true
```

## numHistoryShards is fixed at 512

If you ever need to change it, **the database must be wiped**. The chart hard-warns about this. Don't.

## Cassandra / Elasticsearch leftovers

`temporal.cassandra.enabled` and `temporal.elasticsearch.enabled` should both be `false`. If you see Cassandra-related errors, check that nobody flipped them on accidentally.
