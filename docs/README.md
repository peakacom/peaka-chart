# Peaka On-Prem Helm Chart — Documentation

This is the operational documentation for the **`peaka-chart`** repository: the single Helm chart that installs Peaka (a data integration platform) into a customer's on-prem Kubernetes cluster.

## How to read these docs

If you are **brand new** to the project, start with [`runbooks/new-engineer-onboarding.md`](runbooks/new-engineer-onboarding.md) — it sequences the rest of this directory and links the tripwire list as required reading.

If you are about to **edit `chart/values.yaml` or a template**, read [`extras/gotchas_invariants.md`](extras/gotchas_invariants.md) first. It's the ten things that quietly break the chart.

If you are **on-call**, jump to [`runbooks/`](runbooks/).

## Repository layout

```
peaka-chart/
├── chart/                  # The Helm chart itself
│   ├── Chart.yaml          # version, appVersion, subchart deps
│   ├── values.yaml         # the single source of truth for tunables (~2150 lines)
│   ├── templates/          # ~105 templates split per-service into folders
│   │   ├── _helpers.tpl    # 135 named templates — all hostname/port/auth lookups live here
│   │   ├── _validation.tpl # mutual-exclusion validation (postgres vs externalPostgres etc.)
│   │   └── <service>/      # one folder per service (deployment + service + extras)
│   └── README.md           # operator-facing install guide (read this first)
├── .drone.yml              # CI: tag-triggered chart packaging + GCS publish
└── docs/                   # ← you are here
```

## Chart facts (snapshot)

| Field | Value |
|---|---|
| Chart version | `1.0.11` (March 2026) |
| App version | `0.3.51` |
| Helm API | `v2` |
| Min Kubernetes | `1.22+` |
| Distribution channel | `gs://peaka-chart/charts/` (GCS bucket, public read) |
| Repo URL | `https://peaka-chart.storage.googleapis.com/charts` |
| Image registry | `europe-west3-docker.pkg.dev/code2-324814/peaka-service-container-images` (private GAR) |
| CI | Drone, kubernetes runner, signed pipeline |

## Doc tree

- **[`architecture/`](architecture/)** — how the system is built and why
  - [`components.md`](architecture/components.md), [`adrs.md`](architecture/adrs.md), [`obsolete.md`](architecture/obsolete.md), [`recommendations.md`](architecture/recommendations.md), [`pain-points.md`](architecture/pain-points.md), [`technologies/`](architecture/technologies/)
- **[`runbooks/`](runbooks/)** — paged in the middle of the night? Start here. Also hosts [`new-engineer-onboarding.md`](runbooks/new-engineer-onboarding.md).
- **[`questions/`](questions/)** — handover material for the outgoing maintainer
- **[`diagrams/`](diagrams/)** — Mermaid system diagrams (one file each)
- **[`extras/`](extras/)** — Helm refresher, glossary, and [`gotchas_invariants.md`](extras/gotchas_invariants.md) (the tripwire list)
