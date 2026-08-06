# Chart verification scripts

Client-side checks for changes to `chart/`. They exist because `helm lint`
validates almost nothing that matters here, and the release pipeline never
renders the chart before publishing it to `gs://peaka-chart/charts/`.

## Quick start

```shell
scripts/verify-chart.sh            # check the working tree
scripts/verify-chart.sh main       # also diff the working tree against main
```

Requires `helm`, `python3` with PyYAML, and `git`. Dependencies are built
automatically if `chart/charts/` is missing.

## What each script is for

| Script | Answers |
|---|---|
| `verify-chart.sh` | Did this change alter what ships, and only in the intended ways? |
| `check_names.py` | Would the API server reject any object name or label value? |
| `check_middleware.py` | Does any IngressRoute reference a Middleware that does not exist, and is routing behaviour unchanged? |

They can be run directly too:

```shell
helm template rel chart/ | python3 scripts/check_names.py -
python3 scripts/check_middleware.py before.yaml after.yaml
```

## Why these three checks specifically

Each one exists because it caught a real defect that the tools already in use
passed cleanly.

**`check_names.py` — `helm lint` does not check name or label limits.** The
limits are not uniform, which is what makes them easy to get wrong:

| Object | Limit |
|---|---|
| most `metadata.name` | RFC 1123 subdomain, ≤253 |
| `Service` / `Endpoints` | RFC 1035 label, ≤63, must start with a letter |
| label **values** | ≤63 |
| `StatefulSet` | pods are `<name>-<ordinal>`, and that pod name is a DNS label in the headless-service record — so ≤63, **not** 253 |

A long `fullnameOverride` renders and lints cleanly, then fails at apply time
with an error that does not name the cause. `peaka.validate.nameLength` in
`chart/templates/_validation.tpl` now fails the render instead — and the limit
it enforces (33 characters) was originally set to 35 because only the
label-value constraint had been measured. This script found that the
StatefulSet constraint binds two characters tighter.

**`check_middleware.py` — comparing names is not enough.** Consolidating five
byte-identical Traefik `Middleware` objects into one missed a sixth consumer:
`search-service` referenced `studio-api`'s copy across three route rules
instead of defining its own. Deleting the per-service copies would have left
dangling `middlewareRef`s, and Traefik silently declines to build a router for
those — a 404, not a loud failure. A name-level diff showed nothing wrong. This
script resolves each route rule to the ordered middleware **specs** it applies
and compares those, which surfaced the problem immediately.

**`verify-chart.sh` — "no behaviour change" is a claim, not a fact.** Most work
in this chart is refactoring, where the whole point is that rendered output
stays the same. Rendering both sides and diffing is the only evidence that
actually supports that claim.

## Known nondeterminism

The bundled Kafka subchart generates a random `kraft-cluster-id` on every
render, so **two renders of the same tree always differ on that one line**. It
is filtered out. If you add another randomly generated value, add it to
`NONDETERMINISTIC` in `verify-chart.sh` or every run will report a spurious
difference.

## What these scripts do NOT cover

They are entirely client-side. They prove the generated YAML is what you
intended; they prove nothing about whether Kubernetes accepts it or the
workloads behave. Still unverified by anything here:

- API-server acceptance, admission webhooks, CRD schema validation
  → closest cheap check: `helm template … | kubectl apply --dry-run=server -f -`
    against a real cluster. Non-persisting, but needs the Traefik CRDs present,
    an existing namespace, and create RBAC.
- Postgres actually executing the `abstract_schema_mapper` init SQL
- Traefik actually routing through the shared middleware
- The `helm upgrade` path, including the brief window during the middleware
  rename described in `chart/README.md`

## Wiring into CI

`.drone.yml` currently has no `helm lint` and no `helm template`. Adding a step
after `helm-package` that runs `scripts/verify-chart.sh` — and making `push`
depend on it — would close that gap. Note that editing `.drone.yml` invalidates
its trailing `kind: signature` HMAC, so it must be re-signed with
`drone sign <owner>/<repo>` afterwards or publishing may break.
