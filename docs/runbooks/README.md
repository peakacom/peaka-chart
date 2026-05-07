# Runbooks

What to do when things go wrong. Each file is self-contained — keep them short.

| File | When to use |
|---|---|
| [install-stuck.md](install-stuck.md) | `helm install` is hanging or pods are CrashLooping on first install |
| [upgrade-stuck.md](upgrade-stuck.md) | `helm upgrade` is failing or rolling out badly |
| [tls-cert-issues.md](tls-cert-issues.md) | TLS handshake failures, self-signed cert errors, "PKIX" stack traces |
| [database-issues.md](database-issues.md) | Postgres / MariaDB / MongoDB connection failures, OOM, full disk |
| [trino-issues.md](trino-issues.md) | Slow queries, OOM, catalog errors |
| [temporal-issues.md](temporal-issues.md) | Schema-setup Job failing, workflows stuck |
| [traefik-routing.md](traefik-routing.md) | 404, 502, JDBC client can't connect |
| [storage-full.md](storage-full.md) | PVC out of space (Postgres/MinIO/Kafka most common) |
| [chart-release.md](chart-release.md) | How to ship a new chart version |
| [secrets-rotation.md](secrets-rotation.md) | Rotate JWT keys, DB passwords, MinIO keys |

## Universal first step

```bash
NS=peaka                  # change to your release namespace
RELEASE=$(helm ls -n $NS -q | head -1)

# Snapshot of the world
kubectl -n $NS get pods,svc,statefulset,deploy,job,pvc
kubectl -n $NS get events --sort-by=.lastTimestamp | tail -50

# Most useful single command
kubectl -n $NS get pods --no-headers | awk '$3!="Running" && $3!="Completed"'
```
