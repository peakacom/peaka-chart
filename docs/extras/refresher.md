# Helm refresher (and how this chart is laid out)

For someone returning to Helm after several years. Skip sections you remember.

## What Helm is, in one paragraph

Helm 3 is a templating engine + release manager for Kubernetes. You write Go-templated YAML in a `chart/` directory, run `helm install <name> <chart>`, Helm renders the templates against `values.yaml` (plus `--set` overrides), submits the manifests to the K8s API, and remembers the release in a Secret in the target namespace. `helm upgrade` re-renders, computes a diff, and applies it. `helm rollback` re-applies the prior release's manifest.

No Tiller, no server-side component (that was Helm 2). Just a CLI and a convention.

## Mental model: a chart = a folder

```
chart/
├── Chart.yaml          # name, version, dependencies
├── values.yaml         # default values
├── charts/             # subchart .tgz files (from `helm dependency build`)
└── templates/
    ├── _helpers.tpl    # named templates (functions). Filenames starting with _ are not rendered as manifests.
    ├── deployment.yaml # rendered as a manifest
    └── ...
```

**Templates** are Go templates. They have access to:
- `.Values` — the merged values
- `.Chart` — Chart.yaml metadata
- `.Release` — the release name, namespace, etc.
- `.Capabilities` — cluster capabilities (`.APIVersions.Has "..."`)
- `.Files` — non-template files in the chart

## The five concepts you'll actually use

### 1. `{{ ... }}` — print a value
```yaml
replicas: {{ .Values.studioApi.replicaCount }}
```

### 2. `{{- ... -}}` — print and strip whitespace
The dash trims whitespace from before/after the directive. Critical for keeping rendered YAML valid.

### 3. `{{- if ... }} ... {{- end }}` — conditionals
```yaml
{{- if .Values.tls.enabled }}
tls:
  secretName: {{ .Values.tls.secretName }}
{{- end }}
```

### 4. `{{- range ... }} ... {{- end }}` — loops
```yaml
{{- range .Values.imagePullSecrets }}
- name: {{ . }}
{{- end }}
```

### 5. `{{- include "name" . | nindent N }}` — call a named template
The killer feature. `include` calls a template defined elsewhere (usually `_helpers.tpl`):
```yaml
{{- include "peaka.labels" . | nindent 4 }}
```

`nindent N` adds a newline and indents by `N` spaces. `indent N` is the same without the newline. Indentation bugs are the #1 cause of broken Helm templates (see commit `e2149c0` in this repo).

## Subcharts

Declared in `Chart.yaml#dependencies`:
```yaml
dependencies:
  - name: postgresql
    version: 13.4.4
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
```

`helm dependency update` fetches them into `charts/`. They render as part of `helm template`. **Top-level keys named after the subchart pass to it** (`postgresql:` in your values goes to the postgresql subchart). `global:` is shared with all subcharts.

`alias:` lets you depend on the same chart twice — this chart depends on `postgresql` *and* `postgresqlbigtable` (alias).

## How this specific chart is organised

```
chart/
├── Chart.yaml                    # 9 subchart deps; chart 1.0.11 / app 0.3.51
├── values.yaml                   # ~2150 lines — the single source of truth
├── README.md                     # operator-facing install guide
├── .helmignore                   # files to skip when packaging
└── templates/
    ├── _helpers.tpl              # 135 named templates — the brain of the chart
    ├── _validation.tpl           # XOR-validation of conflicting flags
    ├── NOTES.txt                 # printed after install (currently 1 line)
    ├── env-configmap.yaml        # one ConfigMap with 80+ env vars used by all backends
    ├── ingress.yaml              # vanilla Ingress (optional, in front of Traefik)
    ├── tls-secret.yaml           # rendered if tls.enabled and no existing secretName
    ├── jwt-rsa-secret.yaml       # rendered from hard-coded keypair (security risk)
    ├── image-pull-secret.yaml    # rendered if peakaContainerRegistryAccessSecret set
    ├── connection-credentials-secret.yaml  # OAuth client IDs/secrets
    ├── permify-postgresql-uri-secret.yaml  # Permify connection URI
    ├── postgresql-initdb-scripts.yaml      # initdb ConfigMap (the abstract_schema_mapper SQL)
    ├── custom-ca-certs.yaml      # ConfigMap of customer CA certs
    ├── validate.yaml             # Calls validation templates
    └── <service>/                # One folder per service: deployment + service + extras
        ├── auth-service/
        ├── studio/               # studio has API + Web split
        ├── trino/                # trino has coordinator + worker + catalog + autoscaler
        ├── temporal/             # temporal has 4 server services + web + admintools + Job
        ├── ingresses/            # 13 IngressRoute CRDs for routing
        └── ...
```

## Step-by-step: my first task

Suppose I want to bump `be-studio-api` to a new tag.

```bash
# 1. Pick the tag (verify it exists in the registry first)
NEW_TAG=v0.0.350

# 2. Edit values.yaml
yq -i ".studioApi.image.tag = \"$NEW_TAG\"" chart/values.yaml

# 3. Render locally to make sure nothing broke
cd chart && helm dependency build && cd ..
helm template testrun chart/ > /tmp/render.yaml
echo $? # 0 means OK
grep "be-studio-api" /tmp/render.yaml | head

# 4. Try installing in a kind cluster (or any non-prod K8s)
kind create cluster
kubectl apply --server-side --force-conflicts -k https://github.com/traefik/traefik-helm-chart/traefik/crds/
helm install testrun chart/ --create-namespace -n peaka

# 5. Watch pods come up
watch kubectl -n peaka get pods

# 6. Once green, commit + tag for release
git checkout -b bump-studio-api
git commit -am "Update image versions"
# (later, separately, bump chart version + tag for release — see runbooks/chart-release.md)
```

## Helm commands cheatsheet

```bash
helm version                          # check installed version (need 3.x)
helm dependency update chart/         # fetch subcharts
helm dependency build chart/          # use cached subcharts in Chart.lock
helm lint chart/                      # static checks
helm template t chart/ -f values.yaml # render to stdout
helm install <rel> chart/ -n <ns>     # apply
helm upgrade <rel> chart/ -n <ns>     # update existing release
helm history <rel> -n <ns>            # see release versions
helm rollback <rel> [-n <ns>]         # to previous release
helm uninstall <rel> -n <ns>          # remove release (PVCs may stay if marked keep)
helm get values <rel> -n <ns>         # see what values were used
helm get manifest <rel> -n <ns>       # see what was applied
helm diff upgrade <rel> chart/        # (plugin) preview changes
```

## When things break: my standard sequence

1. Render locally first — `helm template ... > /tmp/render.yaml`. Inspect for empty fields, duplicated keys, broken indentation.
2. `helm install --debug` for verbose output.
3. `kubectl describe pod` and `kubectl logs` on whatever's not Running.
4. `kubectl get events --sort-by=.lastTimestamp` is more useful than logs sometimes.
5. Compare current release manifest to a known-good one: `helm get manifest <rel> > /tmp/now; diff /tmp/now /tmp/known-good`.

## Things specific to this chart that surprised me

- The chart embeds **SQL migration scripts** (`abstract_schema_mapper`) inline in a Helm helper. That schema is critical — if you ever need to update it, the source of truth is the chart, not a separate `migrations/` folder.
- Image tags are **per-service**, not "Peaka 1.0.11". Don't try to align them.
- `_helpers.tpl` is 2826 lines. Most of that is the SQL dump. Don't be intimidated.
- The chart depends on Traefik CRDs being installed *before* `helm install`. The README has the `kubectl apply` command for that.
- Subchart values are HUGE — `temporal.*` alone is ~250 lines, mostly defaults inherited from upstream that we don't use.
