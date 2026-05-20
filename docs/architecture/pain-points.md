# Pain points (last 5 months of git history)

Method: scanned commits since 2025-12-06 for keywords (`fix`, `revert`, large diffs, hotfix-like patterns) and themed clusters of consecutive commits in the same area. Top 10 below.

## 1. Custom CA certificate handling — drawn-out battle (Mar 23 – Apr 14, 2026)

Commits: `50c802a` → `8031656` → `66c35b6` → `08aa5c7` → `b263c03` → `9cdc079`

A six-week saga. Started as "configure tls file for minio", escalated to a 33-file refactor (`66c35b6`, +576/-77), then needed another patch a week later for **multi-cert chain imports** (`9cdc079` — single-cert PEM bundles silently broke `keytool` so they had to `csplit` apart certs and import each).

**What this tells you.** TLS-to-internal-services on customer clusters is the #1 hassle. Every JVM and Node service needs the same trust store. Plan for a long debugging tail when a customer ships you a non-standard CA.

## 2. Temporal store TLS configuration (Apr 7–8, 2026)

Commits: `8efb268`, `bf41ff8`, `6a87cf1`, `b1e9fb2`

Four commits in two days adding TLS to Temporal's Postgres connection — then disabling it by default a day later. The "Disable TLS by default in temporal store" commit signals a real customer install broke because TLS got enabled without the right CA chain.

**What this tells you.** TLS-on-by-default is dangerous when downstream stores aren't ready. Default to off and let the operator opt in.

## 3. MongoDB connection URI evolution (Feb 13 – Apr 17, 2026)

Commits: `9cc7c09`, `17a9df1`, `00074a0`, `068921d`, `e1d9112`, `c3c195f`

Six iterations on building the MongoDB URI: TLS support, `connection_uri` override, `mongodb+srv://` scheme, additional query parameters, then final form. The `peaka.mongodb.url` template in `_helpers.tpl` (line 864) is now ~40 lines of careful Helm to assemble that URL.

**What this tells you.** Customer-supplied external MongoDB came with surprises. Each new URI feature was forced by a real install. Don't simplify this template — the complexity earned its keep.

## 4. Hive metastore: MySQL vs Postgres swap (Feb 10–12, 2026)

Commits: `de11cac`, `d649d02`, `f750ddb`, `5316652`, plus validation `db325a8`

A full week of work to add Postgres as a metastore option, then immediately revert the default to MySQL/MariaDB and ship validation logic to fail fast if both are enabled. The `_validation.tpl` file was created (`94cc7d6`, "Move validation templates to separate file") in response.

**What this tells you.** The MariaDB→Postgres pull is real but not done. If a customer asks for "fewer databases", point them at `hiveMetastore.metastoreType: postgres` + `mariadb.enabled: false`.

## 5. `nindent` rendering bug across 30 files (Feb 24, 2026)

Commit: `e2149c0` — "Fix nindent issue on tolerations call" (30 files, +33/-45)

A single-line indentation bug in the common `peaka.common.tolerations` helper that broke YAML rendering across every service. Took 30 file touches to fix because the call sites embedded it inline.

**What this tells you.** Helper-function bugs hit the *whole chart* at once. Lint and `helm template` against a few `values-*.yaml` matrices in CI before merging template-helper changes.

## 6. PostgreSQL big-table buffer rollout (Feb 4–6, 2026)

Commits: `d8c0589` ("Add bigtable buffer postgres helm dependency"), `de98ddf` ("Set BIGTABLE_BUFFER_DB_USERNAME from postgresqlbigtable"), `661b2a8` ("Add S3 bucket environment variables")

A second Postgres instance added to handle a high-write workload. Initial commits had wrong env var sources, requiring a follow-up. The architecture decision is sound (ADR-004); the execution had a stumble.

## 7. The "Disable Network Policy for Redis" workaround (Mar 17, 2026)

Commit: `d7907fe` — `redis.networkPolicy.enabled: false`

Default Redis NetworkPolicy locked out cross-namespace clients. Disabled by default. **Smell.** Network policies are the thing you want enabled in production — disabling globally because of a cross-ns issue is a Band-Aid. Worth revisiting.

## 8. TLS secret support added late (Mar 19, 2026)

Commit: `5c699e0` — "Support using existing TLS secret" (15 files, +20/-16)

Until this commit, TLS termination required pasting cert+key into `values.yaml`. Customers obviously couldn't put production keys in version control. Adding `tls.secretName` was clearly forced by deployment friction.

**What this tells you.** Every "support using existing X" commit reflects a real customer who couldn't use the inline path. Default to the secret-name path when documenting.

## 9. The "Trino missing password file mount" hotfix (Apr 13, 2026)

Commit: `bb125f8` — "Add missing trino password file mount" (1 file, +12)

A volume mount that should have been there since a prior commit was missing. Trino's password-auth path didn't work until this. Single-file fix but signals authentication-related Trino changes are under-tested.

## 10. The `Fix slash appearing when tls is false` saga (Feb 13, 2026)

Commit: `7af530e`

Tiny commit, but the bug was that an env var like `STUDIO_API_HOST` was being rendered as `https:///` (double slash) when TLS was off, breaking the frontend. The fix is two characters. The pain is the **debugging time** — operators install, get a blank Studio page, no obvious error.

**What this tells you.** Render-time URL construction is brittle. Tiny pieces of fence-post logic. The `_helpers.tpl` URL builders deserve a unit-test harness (`helm template -f tests/values-tls-on.yaml` + grep for `://`).

---

## Pattern summary

The recurring themes:

- **TLS / certificate chains** are the #1 source of pain (items 1, 2, 8 above; ~30% of fix commits).
- **External-DB connection URIs** are almost as painful (items 3, 4, 6).
- **Helper-template bugs** have outsized blast radius (item 5).
- **Defaults that are too aggressive** cause hotfixes (items 2, 7).

The meta-lesson: **a CI step that runs `helm template` on a matrix of representative values files would catch most of these in PRs**, not in customer installs.
