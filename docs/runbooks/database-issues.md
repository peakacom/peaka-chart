# Database issues

## Postgres

### Pod crashes with `out of disk space`
```bash
kubectl -n $NS exec <release>-postgresql-0 -- df -h /bitnami/postgresql
```

**Resize the PVC:**
```bash
kubectl -n $NS edit pvc data-<release>-postgresql-0
# change spec.resources.requests.storage to e.g. 20Gi
```

Storage class must support online resize (`allowVolumeExpansion: true`). Otherwise you must scale down, take a logical backup, recreate.

### Connection refused / too many clients
```bash
kubectl -n $NS exec <release>-postgresql-0 -- \
  psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
# Default max_connections=1000 — chart-set in values.yaml#postgresql.primary.extendedConfiguration
```

If close to 1000, find leaks:
```bash
kubectl -n $NS exec <release>-postgresql-0 -- \
  psql -U postgres -c "SELECT application_name, count(*) FROM pg_stat_activity GROUP BY 1 ORDER BY 2 DESC;"
```

### Replication / Galera issues for MariaDB
Single-node Galera in this chart — replication isn't actually used. If you ever scale up `mariadb.replicaCount`, you'll need to think about Galera bootstrap order. Don't, unless you really want HA Hive metastore.

## MongoDB

### `auth failed` after enabling auth
**Cause.** Default install has `mongodb.auth.enabled: false`. Once data exists, flipping it to `true` requires manual user creation.

**Fix.**
```bash
kubectl -n $NS exec <release>-mongodb-0 -- mongo --eval '
  use admin;
  db.createUser({user: "admin", pwd: "secret", roles: ["root"]});
'
# Then helm upgrade with auth.rootPassword set.
```

### Sharedb pod can't connect after URI change
**Cause.** Mongo URI rendering bugs are common (see pain-points). Verify what got rendered:
```bash
kubectl -n $NS exec deploy/<release>-be-collab-sharedb -- env | grep SHAREDB_MONGO
```

If it has `mongodb:////` (4 slashes) or missing port, file a chart bug.

## MinIO

### Buckets gone after upgrade
**Cause.** PVC was deleted (resource policy was removed/changed).

**Recovery.** From a backup, restore object data. Without a backup, this is data loss.

### `403 SignatureDoesNotMatch`
**Cause.** Access key / secret key mismatch between MinIO and what services have in `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` env.

```bash
kubectl -n $NS get secret <release>-minio -o jsonpath='{.data.rootUser}' | base64 -d
kubectl -n $NS exec deploy/<release>-be-studio-api -- env | grep MINIO_
```

These should match. If you rotated MinIO creds outside Helm, sync `hiveMetastore.minioAccessKey/SecretKey` in values.

## Common: backups

The chart ships **no backup mechanism** for any database. The customer is on the hook. Recommended cadence:

- Postgres: pg_dump to MinIO daily; retain 14 days.
- MongoDB: mongodump similarly.
- MinIO: replicate to a second bucket (mc mirror) or rely on customer's storage backups.

Sketch:
```bash
kubectl -n $NS exec <release>-postgresql-0 -- \
  pg_dumpall -U postgres > backup-$(date +%F).sql
```
