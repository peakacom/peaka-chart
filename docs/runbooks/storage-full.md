# Storage full

The chart provisions PVCs at 4Gi default for several services. Real workloads fill these.

## Find the culprit

```bash
kubectl -n $NS get pvc
for pvc in $(kubectl -n $NS get pvc -o name); do
  pod=$(kubectl -n $NS describe $pvc | awk '/Used By:/ {print $3}')
  echo "$pvc -> $pod"
done

# Per-pod disk usage
kubectl -n $NS exec <release>-postgresql-0 -- df -h /bitnami/postgresql
kubectl -n $NS exec <release>-minio-0 -- df -h /export
```

## Resize a PVC online

Works only if the StorageClass has `allowVolumeExpansion: true`.

```bash
kubectl -n $NS edit pvc <name>
# change spec.resources.requests.storage to e.g. 50Gi

# Force the underlying pod to re-bind:
kubectl -n $NS delete pod <pvc-mounting-pod>  # only if storage class needs reattach
```

## When you can't resize

1. Take a logical backup (pg_dump, mongodump, mc mirror).
2. Scale workload to 0.
3. Delete PVC + PV.
4. Update values to set higher PVC size.
5. `helm upgrade`.
6. Restore.

For Postgres specifically, `helm.sh/resource-policy: keep` is **not** set on the primary PVC by default — verify before deleting.

## Kafka log-segment fills

`kafka.extraConfig: log.retention.hours=12` should keep this small. If it's still filling:
```bash
kubectl -n $NS exec <release>-kafka-controller-0 -- \
  kafka-log-dirs.sh --bootstrap-server localhost:9092 --describe | head
```

A stuck consumer holding offsets prevents log compaction. Delete the consumer group:
```bash
kafka-consumer-groups.sh --bootstrap-server localhost:9092 --delete --group <name>
```

## MinIO buckets full

```bash
kubectl -n $NS exec <release>-minio-0 -- mc admin info local
```

Lifecycle policies for old data:
```bash
mc ilm rule add --expire-days 30 local/<bucket>
```
