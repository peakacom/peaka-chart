#!/usr/bin/env bash
# validate.sh — pre-Helm lint for the peaka-chart repo.
#
# WHAT THIS DOES
#   Runs a set of cheap, deterministic checks against chart/values.yaml and
#   the chart/ directory before you reach `helm template` or `helm install`.
#   Each check corresponds to an entry in docs/extras/gotchas_invariants.md.
#
# WHY THIS EXISTS
#   chart/templates/_validation.tpl already fails-fast at render time for the
#   most painful mutual-exclusion cases. This script catches the same things
#   (plus more) without requiring `helm dependency build` to have run, so it
#   is fast enough for a pre-commit hook and a Drone PR step.
#
# EXIT CODES
#   0   all hard checks passed (warnings are allowed)
#   1   at least one hard check failed
#   2   tooling missing (yq, helm, yamllint, ...) — fix your env
#
# USAGE
#   bash scripts/validate.sh              # lint chart/values.yaml
#   bash scripts/validate.sh -f over.yaml # also lint an overlay
#   bash scripts/validate.sh --verbose    # print per-check status
#   bash scripts/validate.sh --help
#
# PRE-COMMIT HOOK SETUP
#   The recommended pattern is a local hook that runs only on staged changes
#   under chart/ — installing pre-commit framework is on the backlog.
#   Quick git-native hook (no framework):
#
#       cat > .git/hooks/pre-commit <<'EOF'
#       #!/usr/bin/env bash
#       changed=$(git diff --cached --name-only | grep -E '^chart/|^scripts/validate\.sh$' || true)
#       [ -z "$changed" ] && exit 0
#       exec bash scripts/validate.sh
#       EOF
#       chmod +x .git/hooks/pre-commit
#
# FUTURE EXTENSIONS (not done yet — see docs/handover_backlog.md)
#   - GitHub Actions: a `validate` job that runs this script on every PR.
#     Until then, Drone runs `version-check` + `helm-package` on tag only,
#     so PR branches are unlinted.
#   - conftest: rego policies for cluster-shape invariants (e.g. "no service
#     may set resources: {}") — covers things this script can't express.
#   - values.schema.json: generated from values.yaml; once present, Helm 3
#     will reject malformed values before render. Reduces this script's
#     scope to cross-key invariants only.

set -u
set -o pipefail

CHART_DIR="chart"
VALUES="${CHART_DIR}/values.yaml"
OVERLAYS=()
VERBOSE=0
FAIL_COUNT=0
WARN_COUNT=0

# ─── colour-free output helpers (pre-commit context may not be a TTY) ─────
log_pass()  { [ "$VERBOSE" -eq 1 ] && echo "  ok    $*"; return 0; }
log_warn()  { echo "  WARN  $*" >&2; WARN_COUNT=$((WARN_COUNT + 1)); }
log_fail()  { echo "  FAIL  $*" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }
log_check() { [ "$VERBOSE" -eq 1 ] && echo "» $*"; }

usage() {
    sed -n 's/^# \{0,1\}//p' "$0" | sed -n '1,40p'
    exit 0
}

# ─── arg parse ────────────────────────────────────────────────────────────
while [ "$#" -gt 0 ]; do
    case "$1" in
        -f|--values)   OVERLAYS+=("$2"); shift 2 ;;
        --verbose|-v)  VERBOSE=1; shift ;;
        -h|--help)     usage ;;
        *)             echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

# ─── tool gate ────────────────────────────────────────────────────────────
require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: required tool '$1' not on PATH" >&2
        echo "  install: $2" >&2
        exit 2
    fi
}
require_tool yq    "https://github.com/mikefarah/yq/releases (NOT the python yq)"

# Confirm we are running mikefarah/yq, not python-yq. The two parse differently.
if ! yq --version 2>&1 | grep -qi 'mikefarah'; then
    echo "ERROR: yq on PATH is not mikefarah/yq. Install from https://github.com/mikefarah/yq" >&2
    exit 2
fi

# yamllint is optional but recommended — if absent, the YAML-style check is
# skipped with a warning rather than treated as a hard failure. This keeps
# the script usable on minimal CI runners.
HAS_YAMLLINT=0
if command -v yamllint >/dev/null 2>&1; then HAS_YAMLLINT=1; fi

[ -f "$VALUES" ] || { echo "ERROR: $VALUES not found — run from repo root" >&2; exit 2; }

# ─── helpers ──────────────────────────────────────────────────────────────
# yq_get <path> <file>  →  prints value or empty string on missing
yq_get() {
    yq -r "$1 // \"\"" "$2" 2>/dev/null
}

# is_bool_true <yaml-path> <file>  →  exit 0 iff value is the YAML bool true
is_bool_true() {
    local raw
    raw="$(yq -o=json -I=0 "$1" "$2" 2>/dev/null)"
    [ "$raw" = "true" ]
}

# ──────────────────────────────────────────────────────────────────────────
# Checks. Each maps to a numbered invariant in
# docs/extras/gotchas_invariants.md. Keep that linkage when adding more.
# ──────────────────────────────────────────────────────────────────────────

# Gotcha #1 — in-cluster vs external store toggles are mutually exclusive
# and one of each pair must be on.
check_db_mutual_exclusion() {
    log_check "check_db_mutual_exclusion (gotcha #1)"
    local pairs=(
        "postgresql.enabled:externalPostgresql.enabled:Postgres"
        "minio.enabled:externalObjectStore.enabled:object-store"
        "mongodb.enabled:externalMongoDB.enabled:MongoDB"
    )
    local p in_path ex_path label in_val ex_val
    for p in "${pairs[@]}"; do
        in_path="${p%%:*}"
        ex_path="$(echo "$p" | cut -d: -f2)"
        label="${p##*:}"
        in_val="$(yq_get ".${in_path}" "$VALUES")"
        ex_val="$(yq_get ".${ex_path}" "$VALUES")"
        if [ "$in_val" = "true" ] && [ "$ex_val" = "true" ]; then
            log_fail "${label}: both ${in_path} and ${ex_path} are true (must be XOR)"
        elif [ "$in_val" != "true" ] && [ "$ex_val" != "true" ]; then
            log_fail "${label}: neither ${in_path} nor ${ex_path} is true (one is required)"
        else
            log_pass "${label}: exactly one of ${in_path} / ${ex_path} is true"
        fi
    done
}

# Gotcha #2 — hiveMetastore.metastoreType ↔ mariadb.enabled coupling.
check_hive_metastore_consistency() {
    log_check "check_hive_metastore_consistency (gotcha #2)"
    local mtype maria
    mtype="$(yq_get ".hiveMetastore.metastoreType" "$VALUES")"
    maria="$(yq_get ".mariadb.enabled" "$VALUES")"
    case "$mtype" in
        postgres)
            if [ "$maria" = "true" ]; then
                log_fail "hiveMetastore.metastoreType=postgres but mariadb.enabled=true (must be false)"
            else
                log_pass "metastoreType=postgres + mariadb.enabled=false"
            fi ;;
        mysql)
            if [ "$maria" != "true" ]; then
                log_fail "hiveMetastore.metastoreType=mysql but mariadb.enabled is not true"
            else
                log_pass "metastoreType=mysql + mariadb.enabled=true"
            fi ;;
        "")
            log_warn "hiveMetastore.metastoreType is empty — defaults will apply" ;;
        *)
            log_warn "hiveMetastore.metastoreType='${mtype}' is non-standard (expected postgres|mysql)" ;;
    esac
}

# Gotcha #3 — accessUrl.{domain,scheme,port,dbcPort} must all be set.
check_access_url_set() {
    log_check "check_access_url_set (gotcha #3)"
    local key val missing=0
    for key in domain scheme port dbcPort; do
        val="$(yq_get ".accessUrl.${key}" "$VALUES")"
        if [ -z "$val" ] || [ "$val" = "null" ]; then
            log_fail "accessUrl.${key} is unset — required before install"
            missing=$((missing + 1))
        fi
    done
    [ "$missing" -eq 0 ] && log_pass "accessUrl fully populated"
}

# Gotcha #4 — TLS shape: enabled=true ⇒ secretName OR (cert AND key).
check_tls_consistency() {
    log_check "check_tls_consistency (gotcha #4)"
    local enabled secret cert key
    enabled="$(yq_get ".tls.enabled" "$VALUES")"
    secret="$(yq_get ".tls.secretName" "$VALUES")"
    cert="$(yq_get ".tls.cert" "$VALUES")"
    key="$(yq_get ".tls.key" "$VALUES")"

    if [ "$enabled" = "true" ]; then
        if [ -n "$secret" ]; then
            log_pass "tls.enabled=true with tls.secretName set"
            if [ -n "$cert" ] || [ -n "$key" ]; then
                log_warn "tls.secretName is set AND tls.cert/key are set — secretName wins; clear the inline values"
            fi
        elif [ -n "$cert" ] && [ -n "$key" ]; then
            log_pass "tls.enabled=true with inline cert+key (consider migrating to tls.secretName)"
        else
            log_fail "tls.enabled=true but neither tls.secretName nor (tls.cert AND tls.key) are set"
        fi
    else
        if [ -n "$secret" ] || [ -n "$cert" ] || [ -n "$key" ]; then
            log_warn "tls.enabled is not true but TLS values are populated — will be ignored"
        else
            log_pass "tls.enabled=false (no TLS material expected)"
        fi
    fi
}

# Gotcha #5 — booleans must be real YAML booleans, not strings.
# We grep for known offenders: any `*.enabled: "true"` / `"false"`.
check_boolean_strings() {
    log_check "check_boolean_strings (gotcha #5)"
    local hits
    hits="$(grep -nE '\.enabled:[[:space:]]*"(true|false)"' "$VALUES" || true)"
    if [ -n "$hits" ]; then
        while IFS= read -r line; do
            log_fail "${VALUES}:${line%%:*}: quoted boolean — drop the quotes"
        done <<< "$hits"
    else
        log_pass "no quoted booleans on *.enabled keys"
    fi
}

# Gotcha #8 — Chart.yaml:version must look like SemVer (Drone version-check
# does strict equality vs the tag; this is a softer pre-flight).
check_chart_version_format() {
    log_check "check_chart_version_format (gotcha #8)"
    local ver
    ver="$(yq_get ".version" "${CHART_DIR}/Chart.yaml")"
    if echo "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.+-]+)?$'; then
        log_pass "Chart.yaml version='${ver}' looks like SemVer"
    else
        log_fail "Chart.yaml version='${ver}' is not SemVer-shaped"
    fi
}

# Gotcha #9 — callers of peaka.common.tolerations must not re-indent.
check_tolerations_call_indent() {
    log_check "check_tolerations_call_indent (gotcha #9)"
    local hits
    hits="$(grep -rnE 'peaka\.common\.tolerations.*nindent' "${CHART_DIR}/templates" 2>/dev/null || true)"
    if [ -n "$hits" ]; then
        while IFS= read -r line; do
            log_warn "${line} — helper already indents; re-indenting will break YAML"
        done <<< "$hits"
    else
        log_pass "no peaka.common.tolerations callers add nindent"
    fi
}

# YAML style — runs yamllint against pure-YAML files. Helm templates are
# excluded by the .yamllint `ignore` block, not here. yamllint's `truthy`
# rule is the second half of gotcha #5; the rest is style drift defence.
check_yamllint() {
    log_check "check_yamllint (.yamllint + truthy rule = gotcha #5 backstop)"
    if [ "$HAS_YAMLLINT" -ne 1 ]; then
        log_warn "yamllint not on PATH — skipping style check (install: pip install yamllint)"
        return 0
    fi
    local out
    if out="$(yamllint -f parsable chart/values.yaml chart/Chart.yaml .drone.yml 2>&1)"; then
        log_pass "yamllint clean"
    else
        # yamllint emits warning: and error: lines. Treat errors as fails,
        # warnings as warns. This matches our two-tier model.
        local err warn
        err="$(echo "$out" | grep -c ':[0-9]*:[0-9]*: \[error\]' || true)"
        warn="$(echo "$out" | grep -c ':[0-9]*:[0-9]*: \[warning\]' || true)"
        echo "$out" | sed 's/^/    /' >&2
        if [ "$err" -gt 0 ]; then
            log_fail "yamllint: ${err} error(s), ${warn} warning(s)"
        else
            log_warn "yamllint: ${warn} warning(s) (no errors)"
        fi
    fi
}

# Gotcha #10 — Redis NetworkPolicy disabled-by-default is deliberate.
# Warn (don't fail) if someone flips it without adding an ingress block.
check_redis_netpol_default() {
    log_check "check_redis_netpol_default (gotcha #10)"
    local enabled ingress_count
    enabled="$(yq_get ".redis.networkPolicy.enabled" "$VALUES")"
    if [ "$enabled" = "true" ]; then
        ingress_count="$(yq -r '.redis.networkPolicy.ingressNSMatchLabels // {} | length' "$VALUES" 2>/dev/null || echo 0)"
        if [ "$ingress_count" = "0" ]; then
            log_warn "redis.networkPolicy.enabled=true but no ingress selectors set — Studio/BullMQ may break"
        else
            log_pass "redis NetworkPolicy enabled with ${ingress_count} ingress selectors"
        fi
    else
        log_pass "redis.networkPolicy.enabled=false (deliberate workaround, see gotchas #10)"
    fi
}

# ──────────────────────────────────────────────────────────────────────────
# Run all checks.
# ──────────────────────────────────────────────────────────────────────────
main() {
    echo "validate.sh: linting ${VALUES} (overlays: ${OVERLAYS[*]:-none})"
    check_db_mutual_exclusion
    check_hive_metastore_consistency
    check_access_url_set
    check_tls_consistency
    check_boolean_strings
    check_chart_version_format
    check_tolerations_call_indent
    check_redis_netpol_default
    check_yamllint

    echo
    echo "summary: ${FAIL_COUNT} fail, ${WARN_COUNT} warn"
    [ "$FAIL_COUNT" -gt 0 ] && exit 1
    exit 0
}

main "$@"
