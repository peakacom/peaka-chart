# Handover backlog

Small follow-ups discovered during the documentation + hardening pass.
Too small for individual tickets, too important to lose. Tackle in priority
order if you have a free afternoon; revisit during quarterly grooming.

Each entry: **what**, **why it matters**, **rough effort**, **pointer to existing context**.

| # | Item | Why it matters | Effort | Pointer |
|---|---|---|---|---|
| 1 | Create `tests/values-*.yaml` matrix (min / tls-on / ext-pg / netpol-on / air-gap) and a `helm template` CI step that renders all five | Catches ~80% of template regressions before tag (per `recommendations.md` P0). Onboarding doc + `validate.sh` already reference this directory. | 0.5 day | `docs/architecture/recommendations.md` §"Add helm lint && helm template pre-commit"; `docs/runbooks/new-engineer-onboarding.md` §4 |
| 2 | Generate `chart/values.schema.json` (e.g. via `helm-values-schema-json`) | Helm 3 will validate user values against the schema automatically; reduces `validate.sh` scope to genuinely cross-key invariants. Catches the quoted-boolean class (gotcha #5) at install time. | 0.5–1 day | `docs/architecture/recommendations.md` P0 |
| 3 | Wire `pre-commit` framework (`.pre-commit-config.yaml`) instead of the hand-installed git hook | `validate.sh` ships setup instructions for a raw `.git/hooks/pre-commit`, which doesn't survive `git clone`. `pre-commit` framework would be uniform across developers. | 1 hr | `scripts/validate.sh` header comment |
| 4 | Add Drone `push` event handler (or `.github/workflows/validate.yml`) that runs `bash scripts/validate.sh` on every PR | Today Drone only runs on `tag`, so feature branches are unlinted. PR feedback latency is currently "next release", which is too late. | 0.5 day | `.drone.yml`; `docs/architecture/recommendations.md` |
| 5 | Create `docs/architecture/repo-anomalies.md` to document deliberate weirdnesses distinct from pain-points and gotchas | `be-iac` has this file; we don't. Examples that belong: the `bitnamilegacy/*` image repository, `redis.networkPolicy.enabled: false`, `chart/.values*.yaml` git-ignored convention, the dual `postgresql` + `postgresqlbigtable` (same chart, different alias). | 1 hr | gap discovered in Step 1 audit |
| 6 | Move customer-overlay convention from `.gitignore` to documented contract (`chart/values-shapes/` with reference files for the four shapes in `README.md` §4) | Today the convention is implicit (`.gitignore` excludes `chart/.values*.yaml`). A reference overlay per shape would make the deployment shapes table real instead of aspirational. | 1 day | repo-root `README.md` §4 |
| 7 | Write an explicit runbook for **multi-cert PEM chain imports** (the `csplit`-per-cert workaround) | `pain-points.md` §1 is a six-week saga; `tls-cert-issues.md` doesn't cover it specifically. Will save the next maintainer a week. | 2 hr | `docs/architecture/pain-points.md` §1; commit `9cdc079` |
| 8 | Render-test for the Trino password-file mount path | `pain-points.md` §9 was a regression in a 1-file path that nobody noticed until customer install. Should have a `helm template -f tests/values-trino-pwd-auth.yaml` matrix. | 2 hr | `pain-points.md` §9; commit `bb125f8` |
| 9 | Chart signing (Sigstore/cosign) on publish | `gs://peaka-chart/charts/` is public-read; integrity rests on TLS + Helm's per-chart digest. Cosign signature in CI would close the supply-chain gap noted in `README.md` §7. | 1 day | `README.md` §7 trust boundary table |
| 10 | Renovate (or similar) for image-tag bumps | "Update image versions" is the most common commit (~20 in 5 months). Manual editing is error-prone — customers find typos before we do. | 0.5 day | `docs/architecture/recommendations.md` P0 |
| 11 | Document the `forwardAuth` middleware integration on the JDBC port (4567) as a tested path | `README.md` §7 notes there is no integration test for this; misrouting the middleware would silently open the JDBC port. | 1 day | `README.md` §7; `docs/diagrams/04-runtime-traffic-flow.mmd` |
| 12 | `CHANGELOG.md` per chart version | Customers cannot today tell `peaka-1.0.10` from `peaka-1.0.11` without `git log`. `Chart.yaml` annotations or `release-notes` per tag would be more discoverable. | ongoing | `docs/runbooks/chart-release.md` |
| 13 | `validate.sh`: add `check_image_pull_keyfile_json` that runs when `-f <overlay>.yaml` includes `imagePullSecret.gcpRegistryAuth.password` | Gotcha #6 is currently prose-only; the script could verify the first character is `{`. Skipped initially because overlays are out-of-tree. | 30 min | `scripts/validate.sh`; gotcha #6 |
| 14 | `validate.sh`: cross-check `Chart.yaml#version` against `git describe --tags --abbrev=0` when run inside a tagged checkout | Today the check is just "is it SemVer-shaped" — strict equality only happens in Drone. A local guardrail would catch tag/version drift before push. | 30 min | gotcha #8 |
| 15 | Resource requests/limits in `values.yaml` | Almost every service has `resources: {}`. On a busy cluster the scheduler binpacks badly and OOMKills are silent. Trino is the only well-tuned component. | 1–2 days | `docs/architecture/recommendations.md` P1 |

## Conventions

When you complete an entry:

1. Delete the row (don't strike-through — this file is supposed to shrink).
2. If the work surfaced a new gotcha, **add it to `docs/extras/gotchas_invariants.md`** with the next number and a matching check in `scripts/validate.sh`.
3. Update `docs/architecture/pain-points.md` if the work fixed a recurring incident.

When you add an entry:

- Include the **pointer** column. A backlog entry without a pointer to existing context decays into "what was this even about?" within a quarter.
- Effort is a rough estimate, not a commitment. If it grows past 2 days, it should graduate to a real issue.
