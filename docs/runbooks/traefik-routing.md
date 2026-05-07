# Traefik routing problems

## 404 on Studio root

**Symptom.** Browser to `http://localhost:8000` returns 404.

**Check.**
```bash
kubectl -n $NS get ingressroute
# expect <release>-fe-studio-app-routes among others
kubectl -n $NS get pod -l app.kubernetes.io/name=<release>-fe-studio-app
```

If the pod isn't `Running`, that's the issue. Otherwise:
```bash
kubectl -n $NS port-forward svc/<release>-traefik 8000:80
curl -v http://localhost:8000
```

If Traefik 404s but the pod is up, check the IngressRoute matches the entrypoint Traefik is listening on (`web` vs `websecure`).

## 502 Bad Gateway

**Cause.** Traefik forwarded but the backend returned an error or didn't respond.

```bash
kubectl -n $NS get pods -l app.kubernetes.io/name=<release>-fe-studio-app
kubectl -n $NS logs deploy/<release>-fe-studio-app
```

For API: `<release>-be-dispatcher` is the backend for `/api`. Check its logs.

## JDBC client cannot connect

**Path.** `traefik:dbc:4567` → forwardAuth middleware → `be-data-rest` → Trino.

**Layered diagnostic:**

```bash
# 1. Is the dbc port exposed by Traefik?
kubectl -n $NS get svc <release>-traefik -o yaml | grep -A3 dbc

# 2. Does the IngressRoute exist?
kubectl -n $NS get ingressroute <release>-dbc-routes -o yaml

# 3. Does forwardAuth (permission service) respond?
kubectl -n $NS exec deploy/<release>-be-data-rest -- \
  curl -s http://<release>-be-permission-service/auth/dbc-custom-header-handling
# Expect 200/403/etc. — anything other than connection refused.

# 4. Does data-rest reach Trino?
kubectl -n $NS exec deploy/<release>-be-data-rest -- \
  curl -s http://<release>-trino:8080/v1/info
```

If forwardAuth fails, the middleware returns 401/403 to the JDBC client.

## Custom domain not working

**Common.** `accessUrl.domain: peaka.example.com` set, but env vars in services have `STUDIO_HOST: http://peaka.example.com:8000` (with the port). Frontend calls then fail because the operator removed `:8000` at the LB.

**Fix.** Set `accessUrl.port:` to the *actual* port your LB exposes (likely 80 or 443). The chart bakes this into env vars at install time.

## TLS handshake fails on `:443`

See [tls-cert-issues.md](tls-cert-issues.md).

## Traefik dashboard

Enabled by default (`globalArguments: --api.dashboard=true`). Port-forward to access:
```bash
kubectl -n $NS port-forward svc/<release>-traefik 9000:9000
# http://localhost:9000/dashboard/
```
