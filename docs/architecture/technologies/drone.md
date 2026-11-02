# Drone CI

A container-native CI system. The pipeline is defined in `.drone.yml` and runs on a Kubernetes Drone runner.

## How this project uses Drone

The pipeline is triggered by:
- `tag` events (`git tag v1.0.12 && git push --tags`) — produces a chart release.
- `custom` events (manual triggers from the Drone UI) — for re-running.

It does **not** run on every push. There is no PR validation pipeline. (See [recommendations.md](../recommendations.md) — adding one is P0.)

## Pipeline steps

1. **`version-check`** — fails if `Chart.yaml#version` doesn't match the git tag (minus `v`).
2. **`helm-package`** — `helm dependency update`, `helm dependency build`, `helm package .`. Produces `peaka-<version>.tgz`.
3. **`get-index-file`** — pulls the existing `index.yaml` from `gs://peaka-chart/charts/`.
4. **`update-index-file`** — `helm repo index . --url https://peaka-chart.storage.googleapis.com/charts --merge index.yaml`.
5. **`push`** — uploads new `index.yaml` and `.tgz` to GCS.

## The signed pipeline

`.drone.yml` ends with:
```yaml
---
kind: signature
hmac: c5f62b224512aa84dafb72d316c75de8799a3c7687fd977052ca7cd691adf87e
```

This is a **Drone HMAC signature** of the YAML above it. Drone re-computes the signature when the pipeline runs and refuses to execute if it doesn't match. **Editing `.drone.yml` requires resigning** — that's why "Update drone signature" appears as commits (`5531c25`, etc.).

To re-sign: `drone sign <repo>` (the maintainer has the secret).

## GCS bucket

The chart is published to `gs://peaka-chart/charts/`. Files:
- `index.yaml` — Helm repo index, merged on every release.
- `peaka-<version>.tgz` — packaged chart artifacts (every released version preserved).

The bucket is **publicly readable**. Customers do `helm repo add peaka https://peaka-chart.storage.googleapis.com/charts` to consume it.

Write access requires the `CHART_BUCKET_WRITER_SA` secret (a GCP service account with bucket-write permission), referenced by Drone secret name. Mounted as `/gcp/gcp-bucket-writer.json` from a `ConfigMap` named `gcp-bucket-writer`.

## Files

- `.drone.yml` — at repo root

## Pitfalls

- The `gcp-bucket-writer` value is a **ConfigMap** that holds the service-account JSON. ConfigMaps are not encrypted at rest by default — the Drone-runner cluster admin should treat this as a sensitive resource.
- No staging/test pipeline exists. A bad chart release goes straight to the public bucket.
- Tag-only triggering means dev branches never get validated.
