# Critical questions for the outgoing maintainer

Two-week handover window. These questions are ordered by **risk if unanswered**: the top of the list will hurt most if you have to figure them out alone after they leave.

## A. Access, accounts, and "who has the keys"

1. **Drone CI access** — what's the URL of the Drone server, who is the admin, and how do I get an account that can re-run pipelines and edit Drone secrets?
2. **HMAC secret for `.drone.yml` signature** — I see `kind: signature, hmac: ...` at the bottom of the file. What's the secret used to compute that, and where is it stored? Without it, I can't make any pipeline changes.
3. **GCS bucket `gs://peaka-chart`** — who owns the GCP project (`code2-324814` based on registry path)? Who can grant me bucket-write access if needed? Is the `CHART_BUCKET_WRITER_SA` ConfigMap rotated regularly?
4. **GCR / Artifact Registry `europe-west3-docker.pkg.dev/code2-324814/...`** — who pushes to this? Does the chart team push the customer-facing Peaka images, or is that another team?
5. **Customer image-pull JSON** — the per-customer `gcpRegistryAuth.password` JSON: where is the master copy? How is a new customer onboarded?

## B. Hidden production state

6. **Hard-coded Permify `account_id: recdK3q5xuwJdGjrh`** — what is this? Is it a default that customers override, or something we ship as-is? It looks like an Airtable record ID.
7. **Hard-coded JWT keypair in `_helpers.tpl`** — am I right that *every* customer install shares this key by default? Is there a real plan to externalize it? Has any customer overridden it?
8. **Default `secretStoreService.secretEncryptionKey: "XXjAe6xLfVWTG5Rf"`** — same question. Customer responsibility to override?
9. **Studio root user `root@onpremise.com / s3cr3t`** — I assume customers change this immediately. Has anyone been bitten by the default leaking?

## C. Architecture you can't see in the code

10. **Why is `metadata-service` a Deployment with a PVC instead of a StatefulSet?** Is there a reason I'm missing, or is it just legacy?
11. **Why does only `be-workflow-worker-express` run as a StatefulSet?** Sticky-task-queue routing? Restartable activities? I want to know what would break if I converted it to a Deployment.
12. **The `deployment-_worker.yaml` filename** in `chart/templates/trino/` — leading underscore. Is the Trino worker actually being rendered by `helm template`? If not, has the chart secretly only had a coordinator for some time?
13. **`accessControl.type: configmap`** branch in Trino — values it references (`refreshPeriod`, `configFile`) don't exist in `values.yaml`. Is this a feature in flight, dead code, or used by a specific customer's overrides?
14. **The `abstract_schema_mapper` SQL dump in `_helpers.tpl`** — where does that schema actually live in the Peaka source tree? When it changes, who updates the dump?
15. **`peaka-trino-byte-manipulation.jar`** — Java agent injected via JVM args in Trino. Where's the source? Who builds it?
16. **The Trino image tag `v1.0.4-onprem.1`** — what's in the Peaka fork on top of upstream Trino?

## D. Operational unknowns

17. **What is the typical customer install size?** (Cluster nodes, RAM, persistent storage). I want to know whether 4Gi default PVCs are realistic.
18. **Does any customer run the chart with `mongodb.enabled=true` and `auth.enabled=false` in production?** That setup ships an unauthenticated Mongo. Is this just for evaluation?
19. **Has anyone ever run with `tls.enabled=true` end-to-end successfully?** Customers seem to flip it off (commit `7af530e` traffic).
20. **Is there a backup tooling story I'm not seeing?** I don't see any backup CronJobs in the chart. Is the customer expected to BYO?
21. **What's the SLA for chart releases?** (Weekly? On-demand?) Is there a deprecation policy for old chart versions?
22. **Has anyone run upgrade from `1.0.5 → 1.0.11` directly?** Are intermediate versions safe to skip, or are there migration steps?

## E. People and process

23. **Who approves chart releases?** Is it just the maintainer's call, or is there review?
24. **Who fields customer support tickets when an install breaks?** Is there a Slack/Linear channel I should join?
25. **Where are the test customers / staging environments?** I'd love a sandbox to break things in before touching real customer-bound chart versions.
26. **The `customEnv` field in the values for `kafkaConnect`** — has any customer ever supplied custom env vars there? What's the use case?
27. **Are there customer-specific values overrides that live elsewhere?** (A separate repo, a vault, an artifact). The chart values feel "demo-default" — I expect production customers run very different values.
28. **"Update drone signature" appears periodically** — what triggers that? Any rotation policy on the HMAC?

## F. Things to just hand me

29. **A working `values-prod.yaml`** from a real customer install (sanitized) — I'll learn 10x faster from this than from the defaults.
30. **The Helm-diff between current and previous releases** the maintainer keeps in their head — "what's different in 1.0.11 from 1.0.10 from a customer's perspective?"
31. **A mental model: which customers are on which chart versions?** I'd like to know who I'm putting at risk if I cut a bad release.
32. **The list of upcoming work** — what's queued up that the maintainer would have done if they stayed?
33. **Known bugs they never had time to fix** — even if they're in a personal Notes app.
34. **One full walkthrough**: maintainer drives a fresh install on a test cluster while I watch. Hands-on > docs.

## G. "I'd want to know this in three months"

35. **What's Peaka's roadmap** for moving away from the umbrella-chart pattern (per-service charts, GitOps)?
36. **Is the chart's image-pull pattern**, `europe-west3-docker.pkg.dev`, fixed forever, or is there a plan to publish to Docker Hub / GHCR?
37. **Any plans to bump Helm v2 → v3 conventions further** (Schema, hooks)?
38. **MariaDB-Galera vs Postgres for Hive metastore** — is there a roadmap to consolidate to one?
39. **`bitnamilegacy/*` migration** — when does this become urgent?

## How to use this list

Schedule **two 1-hour calls** with the maintainer in the first week:
- Call 1: sections A, B, E (access + secrets + people).
- Call 2: sections C, D, F, G (architecture + operations + handover artifacts).

Record both calls. Take live notes into a shared doc the maintainer can correct. Section G can be email follow-up if they're already gone — these are less urgent.
