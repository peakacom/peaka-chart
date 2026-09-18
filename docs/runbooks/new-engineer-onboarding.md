# New engineer onboarding

You're picking up the `peaka-chart` repo. This page exists so you can be useful on day one without reading all of `docs/`.

Budget: **~45 minutes** to read everything linked from this page. After that, you can fix a bug or ship a chart bump without supervision.

## 1. Read the tripwire list first — really

**[`../extras/gotchas_invariants.md`](../extras/gotchas_invariants.md) — required reading before editing any `chart/values.yaml` line or any template under `chart/templates/`.**

It's a numbered list of ten things that quietly break the chart if you violate them. Most have bitten someone in the last six months. Reading it once will save you a day of debugging.

## 2. Skim, in this order

1. **[`chart/README.md`](../../chart/README.md)** — the operator-facing install guide. This is what customers read. Know what they know.
2. **[`../extras/refresher.md`](../extras/refresher.md)** — Helm-and-this-chart refresher. If you've used Helm before, 5 minutes; if not, 15.
3. **[`../architecture/components.md`](../architecture/components.md)** — what each pod is. Scan, don't memorise.
4. **[`../architecture/pain-points.md`](../architecture/pain-points.md)** — the last 5 months of incidents, themed. Tells you where the bodies are buried.
5. **[`../diagrams/01-overall-system.md`](../diagrams/01-overall-system.md)** — visual map of the release pipeline + a customer install.

## 3. Set up your local toolchain

You need:

| Tool | Min version | Why |
|---|---|---|
| `helm` | 3.12+ | `helm template`, `helm lint`, `helm dependency build` |
| `yq` (mikefarah, **not** the Python one) | 4.x | `scripts/validate.sh` uses it heavily |
| `yamllint` | 1.32+ | catches indentation drift before render |
| `kubectl` | 1.22+ | matches the chart's minimum cluster version |
| Optional: `jq` | any | for poking secret JSON keyfiles |

Verify:

```bash
helm version --short
yq --version    # must print "mikefarah/yq"
yamllint --version
bash scripts/validate.sh --help
```

## 4. Make your first change safely

The minimum-viable PR loop:

```bash
# 1. Make your change in chart/values.yaml or chart/templates/

# 2. Lint locally
bash scripts/validate.sh --verbose

# 3. Render against the default values
cd chart && helm dependency build && helm template . > /tmp/out.yaml && cd ..

# 4. (Optional) Render against representative scenarios
helm template chart/ -f tests/values-tls-on.yaml > /tmp/out-tls.yaml
helm template chart/ -f tests/values-ext-pg.yaml > /tmp/out-ext-pg.yaml

# 5. Commit and open a PR
```

> The `tests/values-*.yaml` matrix is on the [handover backlog](../handover_backlog.md) — if it doesn't exist yet, render with the default `chart/values.yaml` only.

## 5. Releasing a chart bump

See [`chart-release.md`](chart-release.md). The two non-negotiables:

- `chart/Chart.yaml:version` and the git tag must match (Drone's `version-check` step enforces this — see [gotcha #8](../extras/gotchas_invariants.md#8-chartyamlversion-must-equal-the-git-tag-without-the-v-prefix)).
- Bump `appVersion` separately from `version` when only image tags changed.

## 6. When you get paged

Go to [`README.md`](README.md) of `runbooks/`. The table maps symptom → runbook. The "Universal first step" snippet at the bottom is the kubectl invocation you'll use 90% of the time.

## 7. Where the docs are dense vs thin

- **Dense** (read carefully): `extras/gotchas_invariants.md`, `architecture/pain-points.md`, `chart/templates/_validation.tpl`, `chart/templates/_helpers.tpl` (the URL builders especially).
- **Thin** (skim): `architecture/technologies/*.md` — one-paragraph orientations to each tool.
- **Aspirational** (proposals, not facts): `architecture/recommendations.md`.

## 8. Handover questions to ask before the previous maintainer leaves

Open [`../questions/important-questions.md`](../questions/important-questions.md) and walk through it with them. Don't read it alone — it's only useful in conversation.

---

**You're done.** If anything in this list led you astray, edit it. This page is supposed to age well; that requires every onboarded engineer to leave it in slightly better shape than they found it.
