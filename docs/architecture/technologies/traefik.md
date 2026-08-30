# Traefik

A reverse proxy and ingress controller. Unlike vanilla `Ingress`, Traefik supports TCP/UDP routing, middlewares, and "IngressRoute" CRDs that are richer than core K8s Ingress.

## How this project uses Traefik

- **Sole north-south entrypoint.** All external traffic — Studio web, REST API, JDBC/DBC — enters through one Traefik service. The chart never deploys vanilla `Ingress` for service routing; it only does so optionally as a wrapper *in front of* Traefik.
- **Three entrypoints** are configured (`values.yaml#traefik.ports`):
  - `web` (8000 → exposed on 80) — HTTP studio + API
  - `websecure` (8443 → exposed on 443) — HTTPS, when `tls.enabled=true`
  - `dbc` (4567) — TCP-ish HTTP for JDBC traffic
- **Routes are defined as `IngressRoute` CRDs** under `chart/templates/ingresses/`. There are 13 of them. Each says "match this path → forward to this Service".
- **One Middleware** is used: `forwardAuth` on the `dbc-ingress-route`. It calls `be-permission-service` to inject `X-Trino-Extra-Credential`, `X-Peaka-User-Id`, `X-Peaka-Api-Key` headers before forwarding to `be-data-rest`. That's how JDBC clients get authenticated against Trino's per-user credentials.

## Routing layout

| URL prefix | Backend | Notes |
|---|---|---|
| `/` (priority 1) | `fe-studio-app` | Catch-all → SPA |
| `/api` (priority 10) | `be-dispatcher` | Application API gateway |
| `/service/studioapi` | `be-studio-api` | |
| `/service/runtimeapi` | `be-runtime-api` | |
| `/service/dispatcher` | `be-dispatcher` | |
| `/service/token-service` | `be-token-service` | |
| `/service/data-rest` | `be-data-rest` | |
| `/service/data-cache` | `be-data-cache` | |
| `/service/cloud-gateway` | `be-cloud-gateway` | |
| `/service/search` | `be-search-service` | |
| `/service/sharedb` | `be-collab-sharedb-ws` | WebSocket |
| `/service/release-state` | `be-release-state` | |
| `/service/workflow-history` | `be-workflow-history` | |
| `dbc:4567` (TCP) | `be-data-rest` (via `forwardAuth`) | JDBC |

## Service exposure modes

`traefik.service.type` toggles how Traefik itself is exposed:

- **`ClusterIP`** (default) — only `kubectl port-forward` to access.
- **`NodePort`** — set `traefik.ports.web.nodePort: 30080` (etc.) to pick fixed node ports.
- **`LoadBalancer`** — provisions an external LB (only if cloud provider supports it).

## TLS

- If `tls.enabled=true`, the chart creates a Secret (or reuses `tls.secretName`) and the IngressRoutes attach `tls: { secretName: ... }` to use the `websecure` entrypoint.
- `peaka.ingress.entryPoint` helper picks `web` or `websecure` based on `tls.enabled`.

## Files

- Subchart values: `chart/values.yaml#traefik`
- Routes: `chart/templates/ingresses/*.yaml`
- Helper that picks entry point: `_helpers.tpl#peaka.ingress.entryPoint`

## Pitfalls

- The Traefik subchart version is pinned at `28.2.0`. Upgrading it can require running `kubectl apply --server-side` on Traefik's CRDs (see `chart/README.md` v1 upgrade notes).
- `kubernetesIngress.enabled: false` means Traefik will NOT pick up vanilla `Ingress` resources. Only `IngressRoute` CRDs.
- Cross-namespace IngressRoutes are disabled (`allowCrossNamespace: false`). All routes and backends must be in the same namespace as the release.
