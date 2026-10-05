# Gotchas & invariants — the tripwire list

**Read this before editing `chart/values.yaml`, `chart/templates/_helpers.tpl`, or `chart/templates/_validation.tpl`.**

This file is the **tripwire list**: things that quietly break the chart if violated. Each entry tells you where the trap lives, what breaks when you spring it, and a cheap way to verify before you ship.

How this file differs from neighbours:

| File | Audience | Time scope |
|---|---|---|
| `extras/gotchas_invariants.md` (this file) | "I'm about to change a value or template" | **Now** — applies to today's edit |
| `architecture/pain-points.md` | "What went wrong historically?" | **Past** — incident narrative |
| `architecture/recommendations.md` | "What should we improve next?" | **Future** — prioritised P0..P3 |
| `runbooks/*.md` | "Production is broken — what do I do?" | **In an incident** |

A subset of these invariants is enforced at chart render time by [`chart/templates/_validation.tpl`](../../chart/templates/_validation.tpl) (`{{- fail }}` calls). Others are checked by [`scripts/validate.sh`](../../scripts/validate.sh) (pre-`helm`). Many are still **operator discipline** — that's why this list exists.

---

## 1. In-cluster vs external store toggles are mutually exclusive — and one must be on

**Where.** `chart/values.yaml:198,220` (`postgresql` / `externalPostgresql`); `:250,260` (`minio` / `externalObjectStore`); `:326,341` (`mongodb` / `externalMongoDB`); `:276` (`mariadb`).

**What breaks.** `helm install` fails with a `{{- fail }}` from `chart/templates/_validation.tpl:1-39` if **both** or **neither** is enabled. The message is clear, but operators editing values blindly hit it on every fresh install.

**Lint check.** `scripts/validate.sh` greps for `enabled: true` under each pair and asserts XOR. Render-time also catches it.

**How to verify.**
```bash
helm template chart/ -f your-values.yaml > /dev/null
# Any output beginning with "Error: execution error" names the invariant.
```

---

## 2. `hiveMetastore.metastoreType` must match the database toggle

**Where.** `chart/values.yaml:232` (`hiveMetastore.metastoreType`) ↔ `:276` (`mariadb.enabled`).

**What breaks.** Render-time fail from `_validation.tpl:11-19`:

- `metastoreType: postgres` **requires** `mariadb.enabled: false`. Otherwise: `"Set mariadb.enabled to false if you want to use PostgreSQL as your metastore."`
- `metastoreType: mysql` **requires** `mariadb.enabled: true`. Otherwise: `"Enable mariadb to use MySQL as your metastore."`

**Why this trips people.** Two unrelated-looking keys are coupled. The default ships `mysql` + `mariadb`; switching one half without the other is a silent edit.

**Lint check.** `scripts/validate.sh::check_hive_metastore_consistency`.

---

## 3. `accessUrl.*` must be set **before** install — it's baked at render time

**Where.** `chart/values.yaml:60-67` (`accessUrl.domain` / `.scheme` / `.port` / `.dbcPort`). Operator-facing doc: [`chart/README.md`](../../chart/README.md) §Configuring Access URLs.

**What breaks.** The values are interpolated into CORS policies, JDBC connection strings, redirect URLs, and frontend bundle env vars during `helm template`. Changing them post-install requires a full `helm upgrade`, not just a pod restart. A wrong scheme (`http` when fronted by HTTPS) yields a **blank Studio page** with no obvious error — historically the `Fix slash appearing when tls is false` saga (see `architecture/pain-points.md` §10).

**Lint check.** `scripts/validate.sh::check_access_url_set` asserts the four fields are non-empty.

---

## 4. `tls.enabled: true` requires **either** `tls.secretName` **or** (`tls.cert` AND `tls.key`)

**Where.** `chart/values.yaml:179-186`.

**What breaks.** `chart/templates/tls-secret.yaml` has `required` clauses for `tls.cert` / `tls.key` when `secretName` is empty — so a half-set `enabled: true` with all three blank fails at render. The trap is the **reverse mistake**: leaving `enabled: false` while populating `cert/key/secretName`, expecting TLS to "just turn on". It won't.

**Operator preference.** Always prefer `tls.secretName` — putting cert + key inline in version control is a footgun (see `pain-points.md` §8).

**Lint check.** `scripts/validate.sh::check_tls_consistency`.

---

## 5. Booleans in `values.yaml` must be real YAML booleans, not strings

**Where.** Any `*.enabled` key. The bug that motivated this: commit `8daa37e` ("Fix boolean interpretation of string value").

**What breaks.** Helm + Go template will coerce `"true"` (string) to truthy in some contexts and not others. A common variant is operators writing `enabled: "true"` in `values.yaml`, then `if .Values.foo.enabled` works but `{{ .Values.foo.enabled | toYaml }}` renders the literal string `"true"` somewhere downstream — and the receiving service (e.g. Trino, Temporal) parses it as `false`.

**Lint check.** `yamllint`'s `truthy` rule will flag `"true"` / `"false"` / `"on"`. We enable it.

---

## 6. `imagePullSecret` operator-supplied content is a JSON **keyfile body**, not a path

**Where.** Operator config: `chart/README.md` §Configuration (lines 50-54). Template: `chart/templates/image-pull-secret.yaml`.

**What breaks.** Operators paste a filename (`/etc/gcp-key.json`) instead of the file's JSON contents. Result: `Secret` is created with garbage, every pod hits `ImagePullBackOff`, and the error is at *pod* level not *helm* level (no fast fail).

**How to verify before install.**
```bash
# What you paste must start with '{' and parse as JSON.
yq -r '.imagePullSecret.gcpRegistryAuth.password' your-values.yaml | head -c 1   # must be '{'
yq -r '.imagePullSecret.gcpRegistryAuth.password' your-values.yaml | jq . > /dev/null   # must exit 0
```

---

## 7. Subchart deps are fetched from **public** Helm repos at package time

**Where.** `chart/Chart.yaml:7-46` (deps: `bitnami`, `minio`, `traefik`, `permify`). CI: `.drone.yml:18-30`.

**What breaks (on-prem).** Air-gapped customers who clone this repo and run `helm dependency build` themselves will fail — no network access to `charts.bitnami.com`, `charts.min.io`, `helm.traefik.io`, `permify.github.io`. The **published** chart tarball (from `gs://peaka-chart/charts/`) ships with subcharts embedded, so the usual path works; but any customer-side rebuild does not.

**On-prem mitigation.** Either ship the packaged `.tgz` (preferred), or pre-fetch deps and mirror them on the customer's internal Helm proxy. Document the chosen path per-customer.

**Lint check.** None at chart level. `scripts/validate.sh` could verify `chart/charts/` is populated before packaging.

---

## 8. `Chart.yaml:version` must equal the git tag without the `v` prefix

**Where.** `chart/Chart.yaml:5`; gate: `.drone.yml:10-21`.

**What breaks.** Drone's `version-check` step compares `cat chart/Chart.yaml | yq '.version'` against `${DRONE_TAG#v}`. Mismatch ⇒ release build fails. Bumping the tag without bumping the chart version (or vice versa) is the most common cause.

**Lint check.** `scripts/validate.sh::check_chart_version_format` warns if the version is not a SemVer triple, and (when run on a tag) cross-checks against `git describe`.

---

## 9. `peaka.common.tolerations` helper already includes `indent 2` — do not re-indent at the call site

**Where.** `chart/templates/_helpers.tpl:107-117`. The helper emits `tolerations:\n` plus a 2-space-indented block.

**What breaks.** A caller doing `{{ include "peaka.common.tolerations" ... | nindent 6 }}` will double-indent and produce invalid YAML across **every service that uses it**. This was the `nindent` bug — commit `e2149c0`, 30 files, that motivated splitting validation into `_validation.tpl` (see `pain-points.md` §5).

**Pattern to copy.**
```yaml
{{- include "peaka.common.tolerations" (dict "tolerations" .Values.foo.tolerations "global" $.Values.global) | nindent 6 }}
# is wrong. Correct:
{{ include "peaka.common.tolerations" (dict "tolerations" .Values.foo.tolerations "global" $.Values.global) }}
```

**Lint check.** `scripts/validate.sh::check_tolerations_call_indent` greps for `tolerations.*nindent` in `templates/` and warns.

---

## 10. `redis.networkPolicy.enabled: false` is a **deliberate workaround**, not an oversight

**Where.** `chart/values.yaml:373`.

**What breaks if you "fix" it.** Re-enabling Redis NetworkPolicy without first adding ingress rules for **cross-namespace** Studio/API/Workflow clients will silently break the Studio web app (Redis-backed sessions) and BullMQ dashboards. The default was flipped to `false` in commit `d7907fe` after exactly this happened in a customer install.

**If you want to re-enable it** (you probably should — see `recommendations.md` P1): scope it per-namespace, run `helm template -f tests/values-netpol-on.yaml` and grep for Redis ingress rules covering every consuming workload's namespace.

**Lint check.** None — this is a *deliberate non-default*. `scripts/validate.sh` emits a warning if you flip it without an accompanying ingress block.

---

## How invariants get added here

Add an entry when:

1. A `{{- fail }}` clause is added to `_validation.tpl` → mirror it here in prose.
2. A commit message contains `Fix`/`Revert` and the diff is in `_helpers.tpl` or a values default → there was a tripwire, document it.
3. A customer support ticket repeats — same wrong configuration causes the same wasted day twice.
4. A reviewer comments "this is non-obvious" on a PR.

Each entry should answer the three questions: **Where? What breaks? How do I verify?** Skip narrative — narrative belongs in `pain-points.md`.
