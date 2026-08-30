# TLS / certificate issues

The most-painful failure category in this chart (see [pain-points.md](../architecture/pain-points.md)).

## Symptoms map to causes

| Stack trace / error | Likely cause |
|---|---|
| `PKIX path building failed` (Java) | Custom CA not in truststore |
| `unable to find valid certification path` | Same |
| `x509: certificate signed by unknown authority` (Go/Node) | Custom CA not in Node bundle |
| Browser `NET::ERR_CERT_AUTHORITY_INVALID` | Traefik serving cert from `tls.cert` is self-signed |
| MinIO `connect: TLS handshake failure` | `externalObjectStore.tls.enabled` mismatch with reality |
| Postgres `SSL connection has been closed` | `externalPostgresql.tls=false` but server requires TLS |

## 1. Add a customer CA cert

```yaml
# values-customca.yaml
global:
  customCACertificates:
    - name: corp-root-ca
      cert: |
        -----BEGIN CERTIFICATE-----
        MIID...                              # full PEM, can be a chain (multiple BEGIN blocks)
        -----END CERTIFICATE-----
```

Apply with `helm upgrade ... -f values-customca.yaml`. **All backend pods restart** (the env ConfigMap they reference changes; they have a checksum annotation).

Verify:
```bash
kubectl -n $NS exec deploy/<release>-be-studio-api -- \
  keytool -list -keystore /truststore/cacerts -storepass changeit | grep -i corp-root
```

## 2. Multi-cert chain not importing

**Background.** Commit `9cdc079` (Apr 14, 2026) fixed this — single PEM file with multiple `-----BEGIN CERTIFICATE-----` blocks now gets `csplit`-ed and imported piece by piece. If you're on chart `<1.0.11`, **upgrade**.

## 3. Traefik TLS not terminating

**Symptom.** `https://...:8443` connects but cert is wrong / browser warns.

**Check.**
```bash
echo | openssl s_client -connect <host>:443 -servername <host> 2>&1 | openssl x509 -noout -subject -issuer
```

**Fix options.**
- If a real cert: `tls.cert` and `tls.key` set, but stale → re-render and `helm upgrade`.
- Better: use `tls.secretName` pointing at a Secret you manage out-of-band (commit `5c699e0` enabled this).

## 4. Postgres TLS to external server

**Symptom.** Backends can't connect to external Postgres with `externalPostgresql.tls: true`.

**Check.**
```bash
kubectl -n $NS exec deploy/<release>-be-studio-api -- \
  env | grep -E "DB_(HOST|SSL|PORT)"
# DB_SSL should be "true"
```

**Fix.** The Java `sslmode=prefer` is what the chart sets. If your server *requires* `verify-full`, customize the JDBC URL via service-specific overrides (currently not supported via values — needs a chart change).

## 5. Temporal store TLS

**Symptom.** Temporal pods crash on startup; `tls: failed to verify certificate`.

**Cause.** `temporal.server.config.persistence.{default,visibility}.sql.tls.enabled: true` but no CA mounted, or CA wrong.

**Fix.** Disable TLS to Temporal Postgres unless explicitly needed (commit `b1e9fb2` made this default-off). Or load CA into a Secret named `postgresql-tls` and ensure `additionalVolumes` mounts it.

## Diagnostic recipes

```bash
# What CAs does a Java service trust?
kubectl -n $NS exec deploy/<release>-be-studio-api -- \
  keytool -list -keystore /truststore/cacerts -storepass changeit | head

# Is JAVA_TOOL_OPTIONS set?
kubectl -n $NS exec deploy/<release>-be-studio-api -- env | grep JAVA_TOOL_OPTIONS

# Can the pod even reach the upstream?
kubectl -n $NS exec deploy/<release>-be-studio-api -- \
  openssl s_client -connect minio.example.com:443 -servername minio.example.com < /dev/null
```
