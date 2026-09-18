# Rotating secrets

## JWT keypair

The keypair is **hard-coded** in `chart/templates/_helpers.tpl` (`peaka.jwt.publicKey` / `peaka.jwt.privateKey`). Every Peaka deployment shares it by default. **Critical security risk.**

### To rotate

1. Generate a new RSA keypair:
   ```bash
   openssl genrsa -out priv.pem 2048
   openssl rsa -in priv.pem -pubout -out pub.pem
   ```
2. Base64-encode each (single line, no newlines):
   ```bash
   base64 -w 0 priv.pem
   base64 -w 0 pub.pem
   ```
3. Two options:
   - **Quick path**: edit `_helpers.tpl` and replace the two literals. Cut a chart release. *This still ships the same key to all installs of that version.*
   - **Right path**: change the chart so the JWT secret is created externally and referenced by name. New values: `jwtSecret.secretName: my-jwt`. Templates read from secret instead of `_helpers.tpl`. (Code change required.)
4. `helm upgrade` — every backend pod restarts because the env ConfigMap checksum (annotation `checksum/config`) changes.

### Validation

```bash
kubectl -n $NS exec deploy/<release>-be-studio-api -- \
  cat /secrets/jwt/rsa/publickey.pem | head -3
```

## Postgres password

```bash
# Pick new password
NEW_PW='change-me-securely'

# Update inside Postgres
kubectl -n $NS exec <release>-postgresql-0 -- \
  psql -U postgres -c "ALTER USER code2db WITH PASSWORD '$NEW_PW';"

# Update Bitnami secret
kubectl -n $NS create secret generic <release>-postgresql \
  --from-literal=password="$NEW_PW" \
  --from-literal=postgres-password=postgres \
  --dry-run=client -o yaml | kubectl apply -f -

# Update values + helm upgrade
helm upgrade $RELEASE chart/ -n $NS \
  --set postgresql.auth.password="$NEW_PW" \
  --reuse-values
```

Pods that read DB_PASSWORD from the env ConfigMap will restart on the upgrade.

## MinIO root credentials

Default: `console` / `console123` (set in `hiveMetastore.minioAccessKey/SecretKey` — confusing nesting).

```bash
helm upgrade $RELEASE chart/ -n $NS \
  --set hiveMetastore.minioAccessKey=newaccess \
  --set hiveMetastore.minioSecretKey=newsecretsecret \
  --reuse-values
```

MinIO itself reads from the upstream Helm chart's secret — verify what values map there in `chart/values.yaml#minio`.

## Studio root user

```yaml
rootUser:
  email: admin@yourcorp.com
  password: a-real-password
```

Change once, before the chart's first `helm install`. Changing afterwards requires manual SQL because Studio stores the user record in `code2db`.

## Connector OAuth credentials

Set in `connector.credentials.provider.<name>`:
```yaml
connector:
  credentials:
    provider:
      google:
        clientId: ...
        clientSecret: ...
```

`helm upgrade` re-renders the secret. The `be-cloud-gateway` / `be-studio-api` services read it.

## Image pull secret

Replace the JSON file from Peaka and re-render:
```bash
helm upgrade $RELEASE chart/ -n $NS \
  --set-file peakaContainerRegistryAccessSecret.gcpRegistryAuth.password=./new-key.json \
  --reuse-values
```

## Permify

The `permify-postgresql-uri-secret` is rendered from Postgres user/password. Bumping Postgres creds (above) propagates here automatically.

## Secret-store encryption key

`secretStoreService.secretEncryptionKey` is the AES key used by `be-secret-store-service` to encrypt at-rest secrets stored in its DB. **Rotating it requires re-encrypting all stored secrets** — Peaka platform has no built-in mechanism for this. Decision: live with it, or coordinate a maintenance window with Peaka engineering.
