# peaka-chart — on-prem Helm chart for Peaka

This is the single Helm chart that installs **Peaka** — a data integration platform — into a customer's on-prem Kubernetes cluster. The chart is built, packaged, and published from this repository; customer operators consume the published tarball, not the source.

If you are a **customer operator** about to install Peaka, read [`chart/README.md`](chart/README.md). This file is for the engineers who maintain the chart.

---

## 1. Installation order (chart maintainer's view)

The end-to-end pipeline from source to a running customer cluster:

```
   chart/values.yaml edits
            │
            ▼
   git tag vX.Y.Z   ──►  Drone CI  ──►  helm package  ──►  gs://peaka-chart/charts/  ──►  customer cluster
                                                                                              │
                                                              helm install peaka/peaka ◄──────┘
                                                              -f values.yaml (+ optional overlays)
```

The non-obvious ordering inside Drone: **`version-check` must pass before `helm-package` runs**. The check is `chart/Chart.yaml#version == DRONE_TAG#v`. If you bumped the tag but forgot the chart version (or vice versa), the build dies at step 1.

The customer-side ordering is documented in [`chart/README.md`](chart/README.md). The non-obvious step is: **install Traefik CRDs separately** *before* `helm install` on first install or any v1 upgrade — `kubectl apply --server-side --force-conflicts -k https://github.com/traefik/traefik-helm-chart/traefik/crds/`.

## 2. Repository structure

```
peaka-chart/
├── chart/                          # the Helm chart itself
│   ├── Chart.yaml                  # version, appVersion, subchart deps
│   ├── values.yaml                 # single source of truth (~2150 lines)
│   ├── templates/                  # ~105 templates, split per-service
│   │   ├── _helpers.tpl            # 135 named templates (URL builders, labels, ...)
│   │   ├── _validation.tpl         # render-time `fail` clauses (XOR rules)
│   │   ├── validate.yaml           # render-time validation manifest
│   │   └── <service>/              # one folder per service
│   ├── README.md                   # customer-facing install guide
│   └── .helmignore
│
├── docs/                           # maintainer documentation
│   ├── README.md                   # doc index — START HERE
│   ├── extras/
│   │   └── gotchas_invariants.md   # ⚠ tripwire list — read before editing
│   ├── architecture/               # components, ADRs, pain points, recs
│   ├── diagrams/                   # Mermaid system diagrams
│   ├── runbooks/                   # incident playbooks + onboarding
│   └── questions/                  # handover material
│
├── scripts/
│   └── validate.sh                 # pre-Helm lint (yq + grep + yamllint + helm lint)
│
├── .drone.yml                      # CI: tag → helm package → GCS publish
├── .yamllint                       # YAML style rules
└── README.md                       # ← you are here
```

## 3. Documentation index

| Read when | Where |
|---|---|
| **You're new and have 45 min** | [`docs/runbooks/new-engineer-onboarding.md`](docs/runbooks/new-engineer-onboarding.md) |
| **You're about to edit `chart/values.yaml` or a template** | [`docs/extras/gotchas_invariants.md`](docs/extras/gotchas_invariants.md) — **Tripwire list — read before editing any `chart/values.yaml` line or any template** |
| Setting up a customer install | [`chart/README.md`](chart/README.md) |
| Architecture, ADRs, pain points | [`docs/architecture/`](docs/architecture/) |
| Production is broken | [`docs/runbooks/`](docs/runbooks/) |
| Visual system map | [`docs/diagrams/`](docs/diagrams/) |
| Releasing a new chart version | [`docs/runbooks/chart-release.md`](docs/runbooks/chart-release.md) |
| Questions to ask the outgoing maintainer | [`docs/questions/important-questions.md`](docs/questions/important-questions.md) |

## 4. Deployment shapes

The chart supports several shapes. A "shape" is a coherent set of `values.yaml` overrides. Most customers map cleanly onto one of these.

| Shape | Use case | Key `values.yaml` overrides | Caveats |
|---|---|---|---|
| **Local demo** | A developer's `kind` / `k3d` cluster, single node | `accessUrl.{domain: localhost, scheme: http}`, all `*.enabled: true` (in-cluster Postgres/Mongo/MinIO/MariaDB), `tls.enabled: false`, `traefik.service.type: ClusterIP` (use `kubectl port-forward`) | Use small `persistence.size` values; the bundled stores are not HA. |
| **HA in-cluster** | Customer cluster, all stores in-cluster, multi-AZ | All `*.enabled: true`, increase Trino worker count, raise `persistence.size`, set `tls.enabled: true` + `tls.secretName`, `traefik.service.type: LoadBalancer` | The bundled subcharts are not tuned for production scale; consider HA mode per subchart and resource requests/limits (currently empty). |
| **External-stores** | Customer brings their own managed Postgres/Mongo/object store | `postgresql.enabled: false` + `externalPostgresql.enabled: true` (and host/port/tls/credentials); same XOR pair for Mongo, MinIO. Often also: `mariadb.enabled: false` + `hiveMetastore.metastoreType: postgres` | See **gotcha #1** and **gotcha #2** in the tripwire list. Mutual exclusion is enforced at render time. |
| **Air-gapped** | Customer has no internet egress | Pre-mirror images to an internal registry; set `global.imageRegistry` and per-service `image.repository`. Operator must use the **packaged** `.tgz` from `gs://peaka-chart/charts/`, NOT `helm dependency build` from source | See **gotcha #7**. Cert chains must be mirrored too — see [`docs/runbooks/tls-cert-issues.md`](docs/runbooks/tls-cert-issues.md). |

These shapes are not enforced anywhere; they are guidance. A real customer overlay typically combines two (e.g. external-stores + air-gapped).

## 5. Install commands in order

Maintainer-side, building a local install for testing:

```bash
# 1. Lint before you render anything
bash scripts/validate.sh --verbose

# 2. Pull subchart dependencies (needs internet)
cd chart && helm dependency build && cd ..

# 3. Render against the default values
helm template chart/ > /tmp/peaka-default.yaml

# 4. Render against a customer overlay (if you have one)
helm template chart/ -f my-overlay.yaml > /tmp/peaka-overlay.yaml

# 5. Apply Traefik CRDs (only on a fresh cluster or v0→v1 upgrade)
kubectl apply --server-side --force-conflicts -k \
  https://github.com/traefik/traefik-helm-chart/traefik/crds/

# 6. Install
kubectl create namespace peaka
helm install peaka chart/ -n peaka -f my-overlay.yaml
```

Customer-side, consuming the published chart:

```bash
helm repo add peaka https://peaka-chart.storage.googleapis.com/charts
helm repo update
kubectl create namespace peaka
helm install peaka peaka/peaka -n peaka -f my-overlay.yaml
```

There are **no shell scripts** in this repo (other than `scripts/validate.sh`). Installation is `helm` only. If you find yourself reaching for an install script, the right move is usually to add an option to the existing chart, not to wrap `helm install` in bash.

## 6. Core facts — before you touch anything

- **Chart distribution.** Packaged tarballs live in `gs://peaka-chart/charts/` (public read). The index is `gs://peaka-chart/charts/index.yaml`. Drone publishes on tag.
- **Image registry.** `europe-west3-docker.pkg.dev/code2-324814/peaka-service-container-images` — **private GAR**. Each customer is given a service-account JSON keyfile; the contents go into `imagePullSecret.gcpRegistryAuth.password` (see **gotcha #6** — it is the JSON body, not a path).
- **One chart, many customers.** There are no in-tree per-customer values files. The convention is `chart/.values<customer>.yaml` (git-ignored — see `.gitignore`). Apply with `helm install -f chart/values.yaml -f chart/.values<customer>.yaml`.
- **Subchart deps fetched on package.** `bitnami` (Postgres, MariaDB, Kafka, MongoDB, Redis, Postgres-bigtable), `minio`, `helm.traefik.io`, `permify.github.io`. Air-gapped customers cannot `helm dependency build` themselves — see **gotcha #7**.
- **Render-time validation.** `chart/templates/_validation.tpl` already enforces the mutual-exclusion invariants (Postgres/Mongo/MinIO, MariaDB↔metastoreType). Skipping `helm template` in local testing means you find these at install time on a real cluster, which is much worse than at render time on a laptop.
- **CI is Drone, not GitHub Actions.** `.drone.yml` is the pipeline. The signature line (`kind: signature`) is HMAC-signed; do not edit `.drone.yml` without re-signing.
- **Helm minimum.** Helm 3.12+ to get `--server-side` and the `lookup` template function. Cluster minimum K8s 1.22 (Traefik v3 CRDs).

## 7. Implicit security model

This section documents trust boundaries that aren't enforced anywhere in code. **They matter precisely because they're invisible.**

| Boundary | Who is trusted | How trust is established | What happens if violated |
|---|---|---|---|
| **`gs://peaka-chart/charts/` ⇄ customer** | Anyone with the URL | Public-read GCS bucket; **no authentication**. Integrity rests on TLS to GCS + Helm's per-chart digest in `index.yaml`. | A man-in-the-middle that breaks TLS to `storage.googleapis.com` could swap chart contents. There is no chart signing today — see `docs/handover_backlog.md`. |
| **Image registry → customer cluster** | Holder of the GAR service-account JSON | Per-customer SA keyfile in `imagePullSecret.gcpRegistryAuth.password`. Keyfile leak = anyone can pull images. | Rotate the SA key; reissue keyfile to the customer; help them `kubectl delete secret` + `helm upgrade`. |
| **Customer cluster ⇄ Peaka cluster** | None | There is **no callback** from the customer cluster to a Peaka-controlled service. Installs are self-contained once images are pulled. | N/A — no callback channel exists by design. |
| **Customer operator ⇄ cluster** | The operator | Whatever the customer cluster uses — kubeconfig, OIDC, cloud IAM. **Peaka does not provide a bastion or VPN.** Network access to the cluster is the customer's problem. | Out of our scope. Document the customer's posture in their handover notes. |
| **Inter-pod traffic in the `peaka` namespace** | All workloads in the namespace | Kubernetes service ClusterIP — no mTLS, no NetworkPolicy by default. Redis NetworkPolicy is **deliberately disabled** (see gotcha #10). | Any pod in the namespace can reach any other. If the customer wants stronger isolation, they layer a service mesh on top. |
| **TLS to Studio (browser-facing)** | Whatever cert the customer provides | `tls.secretName` (preferred) or inline `tls.cert`+`tls.key`. If `tls.enabled: false`, traffic is plaintext over the LB. | Customer responsibility. We provide the toggle; we don't enforce the choice. |
| **JDBC port (4567) authentication** | `forwardAuth` middleware → `be-permission-service` | Every JDBC connection is intercepted by Traefik middleware, which calls `/auth/dbc-custom-header-handling` on the permission service for `X-Trino-Extra-Credential` headers. If the middleware misroutes, the JDBC port is wide open. | Test JDBC auth on every chart upgrade — there is no integration test for this path. |
| **Custom CA certificates** | The customer (they choose what to trust) | `global.customCACertificates` is imported into every Java truststore and Node.js CA bundle in the chart. | A malicious CA in this list means the cluster trusts that CA's certs for ALL services. Treat as production-secret material. |

**What is not on this list — because it doesn't exist:**

- No central auth service that customers federate with us.
- No "phone home" telemetry.
- No SBOM, no chart signing, no image signing (yet — see backlog).
- No assumption of cloud IAM. This is a Helm chart; trust ends at the cluster boundary.

---

For anything not covered here, the doc index in §3 is the next stop. If you find a gap, the etiquette is: **fix the docs in the same PR as the code, or open a follow-up entry in [`docs/handover_backlog.md`](docs/handover_backlog.md).**
