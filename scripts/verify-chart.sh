#!/usr/bin/env bash
# verify-chart.sh - prove a chart change did, or did not, alter what ships.
#
# WHY THIS EXISTS
#   The release pipeline never renders the chart, and `helm lint` checks almost
#   nothing that matters. Refactors here are judged by one question: does the
#   rendered output change in exactly the ways intended, and nothing else? This
#   makes answering that a single command instead of an afternoon.
#
# WHAT IT DOES
#   1. renders the working tree
#   2. checks names and label values against Kubernetes limits (scripts/check_names.py)
#   3. audits Traefik routing for dangling middlewareRefs and unused Middlewares
#   4. if given a git ref, renders that ref too and compares both the raw
#      manifests and the resolved Traefik routing behaviour
#
# USAGE
#   scripts/verify-chart.sh                 # check the working tree only
#   scripts/verify-chart.sh main            # also diff the working tree against main
#   scripts/verify-chart.sh HEAD~3          # ...or any other ref
#   VALUES="--set tls.enabled=true" scripts/verify-chart.sh main
#
# EXIT CODES
#   0  all checks passed
#   1  a check failed
#   2  missing tooling
#
# NOTE ON NONDETERMINISM
#   The bundled Kafka subchart generates a random kraft-cluster-id on every
#   render, so two renders of the SAME tree always differ on that one line. It
#   is filtered out below. If you add another randomly generated value, add it
#   to NONDETERMINISTIC or every run will report a spurious difference.
set -euo pipefail

REF="${1:-}"
VALUES="${VALUES:-}"
RELEASE="${RELEASE:-verify}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="$REPO_ROOT/chart"
SCRIPTS="$REPO_ROOT/scripts"

NONDETERMINISTIC='kraft-cluster-id'

for tool in helm python3 git; do
  command -v "$tool" >/dev/null || { echo "error: $tool not found" >&2; exit 2; }
done
python3 -c 'import yaml' 2>/dev/null || { echo "error: PyYAML required (pip install pyyaml)" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -d "$CHART_DIR/charts" ]; then
  echo "==> chart/charts missing; running helm dependency build"
  helm dependency build "$CHART_DIR" >/dev/null
fi

render() { # render <chart-dir> <output-file>
  # shellcheck disable=SC2086
  helm template "$RELEASE" "$1" $VALUES > "$2"
}

echo "==> rendering working tree"
render "$CHART_DIR" "$WORK/after.yaml"
echo "    $(grep -c '^kind:' "$WORK/after.yaml") objects"

status=0

echo
echo "==> Kubernetes name and label limits"
python3 "$SCRIPTS/check_names.py" "$WORK/after.yaml" || status=1

echo
echo "==> Traefik routing audit"
python3 "$SCRIPTS/check_middleware.py" "$WORK/after.yaml" || status=1

if [ -n "$REF" ]; then
  echo
  echo "==> rendering $REF for comparison"
  git -C "$REPO_ROOT" rev-parse --verify "$REF" >/dev/null 2>&1 \
    || { echo "error: '$REF' is not a git ref" >&2; exit 2; }
  mkdir -p "$WORK/ref"
  git -C "$REPO_ROOT" archive "$REF" | tar -x -C "$WORK/ref"
  # chart/charts is gitignored, so the archive has no dependencies. Reuse the
  # already-built ones rather than downloading them again.
  cp -r "$CHART_DIR/charts" "$WORK/ref/chart/charts"
  render "$WORK/ref/chart" "$WORK/before.yaml"

  echo
  echo "==> manifest diff vs $REF (excluding $NONDETERMINISTIC)"
  if diff -u \
      <(grep -v "$NONDETERMINISTIC" "$WORK/before.yaml") \
      <(grep -v "$NONDETERMINISTIC" "$WORK/after.yaml") > "$WORK/diff.txt"; then
    echo "    IDENTICAL - this change does not alter rendered output"
  else
    echo "    $(grep -cE '^[+-]' "$WORK/diff.txt") changed line(s). Review them:"
    sed -n '1,60p' "$WORK/diff.txt" | sed 's/^/      /'
    total=$(grep -cE '^[+-]' "$WORK/diff.txt")
    [ "$total" -gt 60 ] && echo "      ... ($total changed lines total)"
    echo "    NOTE: a non-empty diff is not automatically a failure. It is a"
    echo "          failure only if it differs from what you intended."
  fi

  echo
  echo "==> resolved Traefik routing: $REF vs working tree"
  python3 "$SCRIPTS/check_middleware.py" "$WORK/before.yaml" "$WORK/after.yaml" || status=1
fi

echo
echo "==> helm lint --strict"
helm lint --strict "$CHART_DIR" || status=1

echo
if [ "$status" -eq 0 ]; then
  echo "==> all checks passed"
else
  echo "==> FAILURES above" >&2
fi
exit "$status"
