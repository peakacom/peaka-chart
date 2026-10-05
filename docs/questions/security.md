# Top 10 security risks

Each entry: **risk** → severity, root cause, the realistic fixes (with trade-offs), and a recommendation.

## 1. Hard-coded JWT signing keypair shared across all installs

**Severity:** Critical. Anyone who looks at `_helpers.tpl` (public via the GCS chart bucket) can forge JWTs valid against every default-installed Peaka deployment.

**Root cause.** `peaka.jwt.publicKey` and `peaka.jwt.privateKey` in `chart/templates/_helpers.tpl` (lines 377–383) embed an RSA keypair as base64 literals. Any service in the chart reads these as the JWT signing/verifying key.

**Fix options.**
- **A. (best) Generate-on-install pattern.** Add a Helm pre-install hook that generates a fresh keypair, stores it in a Secret marked `helm.sh/resource-policy: keep`. All services read from the Secret, not the helper.
  - *Pro:* zero operator burden, unique key per install.
  - *Con:* requires a Bash/openssl-capable image in the hook; chart change is non-trivial.
- **B. Operator-supplied.** Add `jwt.privateKey` / `jwt.publicKey` values; require the operator to set them.
  - *Pro:* simple chart change.
  - *Con:* burdens every operator; defaults will still be embedded (or the chart will fail-fast — pick one).
- **C. External Secret reference only.** `jwt.secretName` field; no inline support.
  - *Pro:* clean separation.
  - *Con:* breaks every existing install that relied on defaults.

**Recommendation.** Path A. Until then, document loudly that customers MUST override.

## 2. Default Studio root credentials

**Severity:** High. Default `rootUser: { email: root@onpremise.com, password: s3cr3t }` lands in the database on first install. If any operator forgets to override **before** install, they ship a compromised admin account that's hard to remove.

**Fix options.**
- **A.** Make `rootUser.password` `required` (Helm `required` template). Fails install if not set.
- **B.** Generate a random password if not set and surface it in `helm install` output (NOTES.txt).

**Recommendation.** Path A — the friction forces operators to think about it. Path B is acceptable but secretly auto-generated passwords get lost.

## 3. Default `secretEncryptionKey` (AES) for secret-store-service

**Severity:** High. `secretStoreService.secretEncryptionKey: "XXjAe6xLfVWTG5Rf"` — 16 bytes, hard-coded. Any encrypted secret stored by the platform is readable by anyone with chart source access.

**Fix.** Same pattern as #1: pre-install hook generates a key into a Secret. Until then, require the operator to set it. **Rotation is hard** — re-encryption of existing stored secrets is a Peaka-engineering problem, not a chart problem.

## 4. MongoDB default-no-auth

**Severity:** High in production, acceptable for evaluation. `mongodb.auth.enabled: false`. Anyone with namespace network access (`<release>-mongodb:27017`) can read/write `sharedb` collaboration data.

**Fix.** Default `mongodb.auth.enabled: true` in next chart release. Generate a random root password (Bitnami chart supports this). Connector services already pull credentials from the secret.

**Trade-off.** Customers running upgrades from default-no-auth installs will hit a one-time auth migration. Document the upgrade path.

## 5. Default Postgres / MariaDB / MinIO credentials are weak literals

**Severity:** High. `code2db/code2db`, `postgres/postgres`, `peaka/peaka`, `console/console123`. All hard-coded defaults.

**Fix.** Same as #2. Either require values or generate at install time. Document override clearly in `chart/README.md`.

## 6. TLS off by default; PLAINTEXT in-cluster everywhere

**Severity:** Medium-High. Depends on cluster trust model. The chart assumes a "trusted in-cluster network" (mesh, no rogue pods). PLAINTEXT to:

- Kafka brokers
- Redis
- MongoDB (when no-auth, also no encryption)
- Postgres (default `sslmode=prefer`, falls back to PLAINTEXT cleanly)
- All HTTP between Peaka services (`http://<release>-be-...`)

**Fix.** Out of scope for the chart alone — depends on cluster-mesh story. If the customer cluster has a service mesh (Istio, Linkerd) doing mTLS, this is OK. If not, large surface area.

**Recommendation.** Document the threat model explicitly: "this chart assumes you have an in-cluster mesh or trusted network".

## 7. NetworkPolicies absent (Redis specifically disabled)

**Severity:** Medium. The chart ships **no** NetworkPolicies. Any pod in the namespace can talk to any other pod (including Postgres / MinIO / MongoDB). Compounded for Redis where the default policy was explicitly disabled (`redis.networkPolicy.enabled: false`, commit `d7907fe`).

**Fix.** Add a baseline NetworkPolicy template that defaults to "deny all, allow same-release". Tunable via `networkPolicy.enabled`.

**Trade-off.** Customers without CNIs that support NetworkPolicy (rare today) will see no effect. Customers with strict policies will appreciate it.

## 8. Image-pull JSON in plaintext values

**Severity:** Medium. `peakaContainerRegistryAccessSecret.gcpRegistryAuth.password` is the GCP service-account JSON. If a customer commits values.yaml with this filled in, it leaks.

**Fix.** The chart already supports `--set-file` from a separate file. **Document loudly** in `chart/README.md` that operators should never paste this into a values file checked into git. Consider rejecting at render time if it looks like JSON inline (heuristic).

## 9. Permify hard-coded `account_id`

**Severity:** Low–Medium (depends on what the field actually controls — looks like an Airtable record ID, possibly used for support/billing tracking). Could leak telemetry or cross-tenant data if it's a real identifier.

**Fix.** Move to a values field. Document clearly. Confirm with maintainer whether this is intended.

## 10. Public chart distribution + public image pull

**Severity:** Low (informational). The Helm chart is published to a public GCS bucket with all defaults visible (the JWT keypair, all weak passwords). The Peaka images themselves are in a private GAR, but the chart manifest reveals: image versions, internal architecture, default credentials — useful intel for an attacker targeting any Peaka customer.

**Fix.** This is a deliberate distribution model. Mitigations:
- Move secrets out of `_helpers.tpl` (fixes #1, #3).
- Don't publish defaults that are exploitable on their own.
- Consider gating chart access (private repo, per-customer signed URL). Trade-off: bigger operator friction.

## Cross-cutting honourable mentions

- **`Trino` plain-text user** — `jdbc:trino://...?user=trino` in env. Trino auth model is `propertyfile`-based (`auth.passwordAuth: ...`) but commented out in default values. Easy way for any in-cluster pod to query Trino.
- **HMAC for Drone signed pipeline** — protects the CI pipeline definition, not the artifact. A leaked HMAC secret means an attacker can push their own pipeline that publishes a poisoned chart.
- **Custom CA mechanism trusts every cert in `/custom-ca-certs/`** — if an operator accidentally mounts a wrong CA bundle, suddenly every JVM trusts an attacker-controlled CA.

## Triage priority

If you have one week to fix three things:

1. **#1 — Generate JWT keypair at install.** Biggest blast radius.
2. **#2 — Make Studio root password required.** Cheapest fix, biggest customer-facing safety.
3. **#5 / #6 + document threat model.** Be honest about what the chart does and doesn't protect.

Everything else can wait for the next chart cycle.
