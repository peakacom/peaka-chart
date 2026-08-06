#!/usr/bin/env python3
"""Check rendered manifests against Kubernetes name and label constraints.

WHY THIS EXISTS
    Neither `helm template` nor `helm lint` validates object names or label
    values. A chart can render perfectly and still be rejected by the API
    server at apply time - or worse, install and leave a StatefulSet whose
    pods cannot resolve their own DNS names.

    The limits are not uniform, which is what makes this easy to get wrong:
      - most metadata.name    RFC 1123 subdomain, <= 253
      - Service / Endpoints   RFC 1035 label,     <= 63, must start a-z
      - label VALUES                              <= 63
      - StatefulSet pods      named <sts>-<ordinal>; that pod name is a DNS
                              label in the headless-service record, so it must
                              fit 63 - not 253

USAGE
    helm template rel chart/ | python3 scripts/check_names.py -
    python3 scripts/check_names.py rendered.yaml [more.yaml ...]

EXIT CODES
    0  no violations
    1  at least one violation
    2  missing dependency (PyYAML)
"""
import re
import sys

try:
    import yaml
except ImportError:
    sys.stderr.write("error: PyYAML is required (pip install pyyaml)\n")
    sys.exit(2)

RFC1123_SUBDOMAIN = re.compile(
    r"^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$"
)
RFC1035_LABEL = re.compile(r"^[a-z]([-a-z0-9]*[a-z0-9])?$")
LABEL_VALUE = re.compile(r"^(([A-Za-z0-9][-A-Za-z0-9_.]*)?[A-Za-z0-9])?$")

# Kinds whose names must be RFC 1035 labels rather than RFC 1123 subdomains.
RFC1035_KINDS = {"Service", "Endpoints"}

# Reserve this much of a StatefulSet's 63-char budget for the "-<ordinal>"
# suffix, so scaling past 9 replicas stays safe.
STS_ORDINAL_RESERVE = 3


def collect_label_maps(node, path, found):
    """Recursively gather every labels/matchLabels map with its location."""
    if isinstance(node, dict):
        for key, value in node.items():
            if key in ("labels", "matchLabels") and isinstance(value, dict):
                found.append((f"{path}.{key}", value))
            collect_label_maps(value, f"{path}.{key}", found)
    elif isinstance(node, list):
        for index, value in enumerate(node):
            collect_label_maps(value, f"{path}[{index}]", found)


def check_name(kind, name, violations):
    if not isinstance(name, str):
        return
    if kind in RFC1035_KINDS:
        if len(name) > 63:
            violations.append(
                (kind, name, "metadata.name",
                 f"{len(name)} chars > 63 ({kind} names must be RFC 1035 labels)")
            )
        elif not RFC1035_LABEL.match(name):
            violations.append(
                (kind, name, "metadata.name",
                 "not an RFC 1035 label (lowercase alphanumeric or '-', must start with a letter)")
            )
        return

    if len(name) > 253:
        violations.append((kind, name, "metadata.name", f"{len(name)} chars > 253"))
    elif not RFC1123_SUBDOMAIN.match(name):
        violations.append((kind, name, "metadata.name", "not an RFC 1123 subdomain"))

    if kind == "StatefulSet":
        budget = 63 - STS_ORDINAL_RESERVE
        if len(name) > budget:
            violations.append(
                (kind, name, "metadata.name",
                 f"{len(name)} chars > {budget}; pod names are <name>-<ordinal> and "
                 f"must fit a 63-char DNS label")
            )


def check_labels(kind, name, doc, violations):
    maps = []
    collect_label_maps(doc, kind, maps)
    for location, mapping in maps:
        for key, value in (mapping or {}).items():
            key_name = key.split("/")[-1]
            key_prefix = key.split("/")[0] if "/" in key else ""
            if len(key_name) > 63:
                violations.append(
                    (kind, name, f"{location}[{key}]",
                     f"label key name part {len(key_name)} chars > 63")
                )
            if key_prefix and len(key_prefix) > 253:
                violations.append(
                    (kind, name, f"{location}[{key}]",
                     f"label key prefix {len(key_prefix)} chars > 253")
                )
            text = "" if value is None else str(value)
            if len(text) > 63:
                violations.append(
                    (kind, name, f"{location}[{key}]",
                     f"label VALUE {len(text)} chars > 63")
                )
            elif not LABEL_VALUE.match(text):
                violations.append(
                    (kind, name, f"{location}[{key}]",
                     f"label value {text!r} contains invalid characters")
                )


def check_stream(stream, label):
    docs = [d for d in yaml.safe_load_all(stream) if d]
    violations = []
    for doc in docs:
        kind = doc.get("kind", "?")
        name = (doc.get("metadata") or {}).get("name")
        check_name(kind, name, violations)
        check_labels(kind, name, doc, violations)

    print(f"=== {label}: {len(docs)} documents parsed ===")
    if not violations:
        print("    no name or label constraint violations")
        return 0
    print(f"    {len(violations)} violation(s):")
    for kind, name, field, message in violations:
        print(f"      [{kind}] {name}")
        print(f"          {field}: {message}")
    return 1


def main(argv):
    targets = argv[1:] or ["-"]
    status = 0
    for target in targets:
        if target == "-":
            status |= check_stream(sys.stdin, "stdin")
        else:
            with open(target) as handle:
                status |= check_stream(handle, target)
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv))
