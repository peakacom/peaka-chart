# MinIO

An S3-compatible object store. Open-source, single-binary, drop-in for AWS S3.

## How this project uses MinIO

- Holds Iceberg data files (the actual rows; Hive metastore holds schema).
- Holds Trino exchange data when `exchangeManager.name=filesystem` is overridden to S3 (default is local fs — see [trino.md](trino.md)).
- Holds connector "blob" data uploaded by Peaka workflows.

The chart deploys MinIO via the official Helm chart at `~5.1.0`:

- `mode: standalone`, `replicas: 1`.
- 4Gi PVC with `helm.sh/resource-policy: keep` (survives `helm uninstall`).
- Default access/secret keys: `console` / `console123` (set via `hiveMetastore.minioAccessKey/SecretKey` — yes, the values are oddly nested under hiveMetastore).

## External S3

Set `externalObjectStore.enabled: true` to use a real S3-compatible service. Fields:

- `host`, `port`, `bucket`, `region`, `tls.enabled`
- `singleBucketMode: false` — if true, all Peaka data shares one bucket; if false, the platform creates per-tenant buckets.
- `accessKey` / `secretKey`

Validation (`_validation.tpl#peaka.validate.objectStore`) enforces that exactly one of `minio.enabled` and `externalObjectStore.enabled` is true.

## Endpoint resolution

`_helpers.tpl#peaka.objectStore.endpoint` produces e.g. `http://<release>-minio:9000` (or the external host). All services reading/writing object data get `MINIO_ADDRESS`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY` from the shared env ConfigMap.

## TLS to MinIO

Recently added (commits `50c802a`, `8031656`, March 2026). When MinIO uses a custom CA, the operator sets `global.customCACertificates`. Each backend service then has an init container that imports the CA into its Java truststore or Node bundle. See ADR-008.

## Files

- Subchart values: `chart/values.yaml#minio`
- External mode: `chart/values.yaml#externalObjectStore`
- Helper: `_helpers.tpl#peaka.objectStore.*`

## Pitfalls

- The MinIO subchart used here is the *upstream* one (charts.min.io), not Bitnami's. It has a different value schema — don't assume Bitnami patterns.
- When using external S3 with a custom CA, all of: `externalObjectStore.tls.enabled`, the right CA in `global.customCACertificates`, *and* matching bucket region must align. Customer installs hit this trap routinely (April 2026 commits).
- `singleBucketMode` toggles a fundamental data layout. **Cannot be flipped after install** without data migration.
