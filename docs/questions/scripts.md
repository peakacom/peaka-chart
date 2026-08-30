# Scripts and frequent commands

There are **no shell scripts in this repo**. Everything is run via `helm` and `kubectl` directly. This file collects the commands I'd expect to run most often.

## Daily / weekly

```bash
NS=peaka
RELEASE=$(helm ls -n $NS -q | head -1)

# Status check
helm ls -n $NS
kubectl -n $NS get pods,svc,pvc,job
kubectl -n $NS get pods --no-headers | awk '$3!="Running" && $3!="Completed"'

# Render the chart locally to debug values
cd chart && helm dependency build && cd ..
helm template testrun chart/ -f chart/values.yaml > /tmp/manifest.yaml

# Diff before applying (requires helm-diff plugin)
helm diff upgrade $RELEASE chart/ -n $NS
```

## Releases

```bash
# 1. Edit chart/values.yaml (image tags) and chart/Chart.yaml (version).
# 2. Commit, tag, push.
git tag v1.0.12 && git push --tags
# Drone takes over.

# Watch the build:
# (open Drone UI in your browser)
```

See [`runbooks/chart-release.md`](../runbooks/chart-release.md) for the full procedure.

## Customer install (the one customers run)

```bash
helm repo add peaka https://peaka-chart.storage.googleapis.com/charts
helm repo update
kubectl create namespace peaka
helm install -n peaka mypeaka peaka/peaka \
  -f my-values.yaml \
  --set-file peakaContainerRegistryAccessSecret.gcpRegistryAuth.password=./peaka-gcr.json \
  --set peakaContainerRegistryAccessSecret.name=peaka-docker-registry
```

## Debugging

```bash
# Logs across all backend services for a pattern
kubectl -n $NS logs -l app.kubernetes.io/instance=$RELEASE --all-containers --tail=50 | grep -i error

# Exec into a service
kubectl -n $NS exec -it deploy/$RELEASE-be-studio-api -- /bin/sh

# Forward Studio to your laptop
POD=$(kubectl -n $NS get pods -l "app.kubernetes.io/name=traefik" -o jsonpath="{.items[0].metadata.name}")
kubectl -n $NS port-forward $POD 8000

# Forward Trino UI
kubectl -n $NS port-forward svc/$RELEASE-trino 8080
# http://localhost:8080  (login: trino, no password)

# Forward Traefik dashboard
kubectl -n $NS port-forward svc/$RELEASE-traefik 9000
# http://localhost:9000/dashboard/

# Postgres CLI
kubectl -n $NS exec -it $RELEASE-postgresql-0 -- psql -U postgres
```

## Helm template snippets to keep handy

```bash
# Render only one service to check changes locally
helm template t chart/ -s templates/studio/studio-api-deployment.yaml

# Render with a specific values matrix
helm template t chart/ \
  -f chart/values.yaml \
  --set tls.enabled=true \
  --set tls.cert="$(cat /tmp/tls.crt)" \
  --set tls.key="$(cat /tmp/tls.key)" \
  > /tmp/render-tls.yaml
```

## Recommended scripts to add

These don't exist today — worth writing during onboarding:

- `scripts/bump-image.sh be-studio-api v0.0.350` — yq-edits values.yaml then `helm template` to validate.
- `scripts/install-test.sh` — installs to a kind/k3d cluster with sane defaults for end-to-end smoke.
- `scripts/diff-release.sh 1.0.10 1.0.11` — shows image-tag diffs between two tags.
- `scripts/extract-values.sh <chart-version>` — `git show v1.0.X:chart/values.yaml`.
