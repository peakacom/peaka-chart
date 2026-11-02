# How to ship a new chart version

## TL;DR

```bash
# 1. Bump image versions in chart/values.yaml (every be-* / fe-* image you want to release)
# 2. Bump chart/Chart.yaml#version (and appVersion if relevant)
# 3. Commit
git commit -am "Update image versions"
git commit -am "Release chart 1.0.12"

# 4. Tag with the SAME version (with leading 'v')
git tag v1.0.12
git push --tags
```

The Drone pipeline does the rest:
1. `version-check` — ensures `Chart.yaml#version` == tag minus `v`. Fails the build otherwise.
2. `helm-package` — pulls subchart deps, packages into `peaka-1.0.12.tgz`.
3. `update-index-file` — merges into the GCS-stored `index.yaml`.
4. `push` — uploads `index.yaml` and `.tgz` to `gs://peaka-chart/charts/`.

Customers running `helm repo update` then see the new version.

## Pre-flight checklist

- [ ] All bumped image tags **exist** in `europe-west3-docker.pkg.dev/code2-324814/peaka-service-container-images`. (No automated check today — add one. See [recommendations.md](../architecture/recommendations.md).)
- [ ] `helm template chart/` renders cleanly with default values.
- [ ] `helm template chart/ -f tests/values-tls.yaml` renders cleanly (if you have such a file — otherwise create one).
- [ ] You ran the chart against a test cluster end-to-end (install + smoke).
- [ ] If you edited `.drone.yml`, you re-signed the pipeline.

## Re-signing `.drone.yml`

```bash
# Maintainer must have the Drone CLI configured against the relevant Drone server,
# and the project's HMAC secret in the Drone DB.
drone sign <org>/peaka-chart --save
```

If you don't have access, the maintainer must do this for you.

## Rolling back a bad release

GCS preserves all uploaded `.tgz` files. Customers pin via `helm install ... --version 1.0.10` to roll back. There's nothing to "delete" from the bucket — `helm repo update` plus a version pin is enough.

If you must withdraw a tag:
```bash
gsutil rm gs://peaka-chart/charts/peaka-1.0.12.tgz
# Regenerate index.yaml:
gsutil cp gs://peaka-chart/charts/index.yaml /tmp/
helm repo index . --url https://peaka-chart.storage.googleapis.com/charts --merge /tmp/index.yaml
gsutil cp index.yaml gs://peaka-chart/charts/
```

## Versioning convention

Inferred from history:
- **`appVersion`** tracks an internal Peaka monorepo version (`0.3.51`).
- **`version`** is the chart version itself (`1.0.x`). Bumped per chart release, regardless of whether app images changed.
- **Image tags** are per-service (`v0.0.349`). No global "Peaka 0.3.51" tag exists on individual images.

The mapping `chart 1.0.11 → which exact image tags?` is **only inferable from the git history of `values.yaml`**. If a customer asks "what image tags shipped in 1.0.7?", `git show v1.0.7:chart/values.yaml | grep tag:` is the answer.
