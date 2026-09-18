# Helm 3

A package manager for Kubernetes. A "chart" is a templated bundle of K8s YAML; `helm install` renders the templates with a values file and applies them to the cluster.

## How this project uses Helm

- **One umbrella chart** (`peaka`) that depends on 9 subcharts (Postgres, MongoDB, Kafka, etc.) declared in `Chart.yaml`.
- Subcharts are downloaded into `chart/charts/` by `helm dependency update` (CI does this).
- `chart/values.yaml` is the **single tunable surface**. Operators override with `helm install --set foo=bar` or `helm install -f my-values.yaml`.
- All template logic lives in `chart/templates/_helpers.tpl` (135 named templates) — service templates only assemble metadata + env + volumes.

## Distribution

The packaged chart `.tgz` is uploaded to a public GCS bucket configured as a Helm repo:

```
helm repo add peaka https://peaka-chart.storage.googleapis.com/charts
helm repo update
helm install -n peaka mypeaka peaka/peaka
```

The `index.yaml` in that bucket is regenerated on every release (Drone step `update-index-file`).

## Helm-specific gotchas in this chart

- **Subchart values bleed in**: any top-level key that matches a subchart name (`postgresql:`, `mongodb:`, `traefik:`) is passed straight to that subchart. Bitnami subcharts have their own conventions (e.g., `auth.postgresPassword`).
- **`global:` is shared with subcharts** — `global.storageClass` propagates everywhere; useful for cluster-wide defaults.
- **`alias:`** in `Chart.yaml` lets us depend on the same chart twice (we depend on `postgresql` *and* `postgresqlbigtable` — both are bitnami/postgresql).
- **Helm hooks** — only Temporal uses them: `helm.sh/hook: post-install,post-upgrade` for the schema-setup Job.
- **The chart is rendered, not generated.** No Kustomize, no Argo CD, no operator. What you see in `templates/` is what hits the cluster.

## Common Helm commands you'll need

```bash
# Render templates without applying — your #1 debugging tool
helm template mypeaka chart/ -f chart/values.yaml

# Install
helm install mypeaka chart/ -n peaka --create-namespace

# Upgrade
helm upgrade mypeaka chart/ -n peaka

# Diff before applying (requires helm-diff plugin)
helm diff upgrade mypeaka chart/ -n peaka

# Uninstall (does NOT delete PVCs by default)
helm uninstall mypeaka -n peaka

# Pull dependencies before render
cd chart && helm dependency update
```

## Where to look in this repo

- Chart manifest: `chart/Chart.yaml`
- Values: `chart/values.yaml`
- All templates: `chart/templates/`
- Most logic: `chart/templates/_helpers.tpl`
- Validation gates: `chart/templates/_validation.tpl`
