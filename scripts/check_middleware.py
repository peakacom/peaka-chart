#!/usr/bin/env python3
"""Compare Traefik routing behaviour between two rendered manifests.

WHY THIS EXISTS
    Diffing rendered YAML by name is not enough to prove a routing change is
    safe. Renaming or consolidating a Middleware changes the names a route
    refers to while the *behaviour* stays identical - and conversely, deleting
    a Middleware that a route still references leaves a dangling middlewareRef
    that Traefik silently refuses to build a router for.

    So instead of comparing names, this resolves every IngressRoute rule to the
    ordered list of middleware SPECS it actually applies, plus its match,
    priority, entryPoints, tls and services, and compares that. Two renders are
    behaviourally equivalent when those resolved chains are equal.

    This caught a real bug: consolidating five identical Middlewares missed a
    sixth consumer (search-service) that referenced another service's copy
    rather than defining its own. A name-level diff showed nothing wrong.

USAGE
    python3 scripts/check_middleware.py before.yaml after.yaml   # compare
    python3 scripts/check_middleware.py rendered.yaml            # audit one

EXIT CODES
    0  equivalent (or, for a single file, no dangling refs and no orphans)
    1  behaviour differs, dangling reference, or unused Middleware
    2  missing dependency (PyYAML)
"""
import json
import sys

try:
    import yaml
except ImportError:
    sys.stderr.write("error: PyYAML is required (pip install pyyaml)\n")
    sys.exit(2)

MISSING = "__MISSING_MIDDLEWARE__"


def load(path):
    """Return (middlewares by name -> spec, IngressRoute name -> route rules)."""
    with open(path) as handle:
        docs = [d for d in yaml.safe_load_all(handle) if d]
    middlewares, routes = {}, {}
    for doc in docs:
        kind = doc.get("kind")
        name = (doc.get("metadata") or {}).get("name")
        if kind == "Middleware":
            middlewares[name] = doc.get("spec")
        elif kind == "IngressRoute":
            routes[name] = doc.get("spec") or {}
    return middlewares, routes


def resolve(middlewares, routes):
    """Expand each route rule into the behaviour it actually produces."""
    resolved, dangling = {}, []
    for route_name, spec in routes.items():
        rules = []
        for rule in spec.get("routes") or []:
            chain = []
            for ref in rule.get("middlewares") or []:
                ref_name = ref.get("name")
                if ref_name in middlewares:
                    chain.append(middlewares[ref_name])
                else:
                    dangling.append((route_name, ref_name))
                    chain.append({MISSING: ref_name})
            rules.append({
                "match": rule.get("match"),
                "kind": rule.get("kind"),
                "priority": rule.get("priority"),
                "services": rule.get("services"),
                "chain": chain,
            })
        resolved[route_name] = {
            "entryPoints": spec.get("entryPoints"),
            "tls": spec.get("tls"),
            "rules": rules,
        }
    return resolved, dangling


def orphans(middlewares, routes):
    used = {
        ref.get("name")
        for spec in routes.values()
        for rule in (spec.get("routes") or [])
        for ref in (rule.get("middlewares") or [])
    }
    return sorted(set(middlewares) - used)


def audit(path):
    middlewares, routes = load(path)
    resolved, dangling = resolve(middlewares, routes)
    unused = orphans(middlewares, routes)
    print(f"=== {path} ===")
    print(f"    {len(routes)} IngressRoute(s), {len(middlewares)} Middleware(s)")
    print(f"    dangling references: {dangling or 'none'}")
    print(f"    unused Middlewares:  {unused or 'none'}")
    return 1 if (dangling or unused) else 0


def compare(before_path, after_path):
    before_mw, before_rt = load(before_path)
    after_mw, after_rt = load(after_path)
    before, before_dangling = resolve(before_mw, before_rt)
    after, after_dangling = resolve(after_mw, after_rt)

    status = 0
    print("=== dangling middleware references ===")
    print(f"    before: {before_dangling or 'none'}")
    print(f"    after:  {after_dangling or 'none'}")
    if after_dangling:
        status = 1

    print("=== unused Middlewares ===")
    print(f"    before: {orphans(before_mw, before_rt) or 'none'}")
    after_unused = orphans(after_mw, after_rt)
    print(f"    after:  {after_unused or 'none'}")
    if after_unused:
        status = 1

    print("=== resolved routing behaviour ===")
    if before == after:
        print("    IDENTICAL - same ordered middleware specs, match, priority, "
              "services, entryPoints and tls for every route")
    else:
        status = 1
        for name in sorted(set(before) | set(after)):
            if before.get(name) != after.get(name):
                print(f"    DIFFERS: {name}")
                print(f"      before: {json.dumps(before.get(name), sort_keys=True)[:700]}")
                print(f"      after:  {json.dumps(after.get(name), sort_keys=True)[:700]}")

    print("=== Middleware inventory ===")
    print(f"    removed: {sorted(set(before_mw) - set(after_mw)) or 'none'}")
    print(f"    added:   {sorted(set(after_mw) - set(before_mw)) or 'none'}")
    return status


def main(argv):
    if len(argv) == 2:
        return audit(argv[1])
    if len(argv) == 3:
        return compare(argv[1], argv[2])
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
