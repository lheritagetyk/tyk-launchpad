#!/usr/bin/env python3
# Scaffold a Tyk SecurityPolicy CRD (Operator), per the official example in
# vendor/tyk-docs/tyk-stack/tyk-operator/create-an-api.mdx. The policy grants access to
# one or more API CRDs by name via access_rights_array, plus rate limit / quota.
#
# IMPORTANT for versioned APIs: a version child has its own API Id, so a policy that only
# lists the BASE will 403 on the child. Pass --api for BOTH the base and each child CRD.
#
#   scaffold-policy.py --name orders-standard --api orders-base --api orders-v2 \
#       --namespace tyk --rate 100 --per 60 --quota 10000 --quota-renewal 3600
import argparse, sys

def yaml_policy(a):
    lines = [
        "apiVersion: tyk.tyk.io/v1alpha1",
        "kind: SecurityPolicy",
        "metadata:",
        f"  name: {a.name}",
        f"  namespace: {a.namespace}",
        "spec:",
        f"  name: {a.display or a.name}",
        "  state: active",
        "  active: true",
    ]
    # rate limit / quota (omit when unset so the policy inherits gateway defaults)
    if a.rate is not None:          lines.append(f"  rate: {a.rate}")
    if a.per is not None:           lines.append(f"  per: {a.per}")
    if a.quota is not None:         lines.append(f"  quota_max: {a.quota}")
    if a.quota_renewal is not None: lines.append(f"  quota_renewal_rate: {a.quota_renewal}")
    lines.append("  access_rights_array:")
    for api in a.api:
        lines += [
            f"    - name: {api}          # references a TykOasApiDefinition by k8s name",
            "      kind: TykOasApiDefinition   # without this the Operator defaults to classic ApiDefinition -> 'not found'",
            f"      namespace: {a.namespace}",
            "      versions:",
            "        - Default",
        ]
    return "\n".join(lines) + "\n"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--name", required=True, help="policy CRD + id name")
    p.add_argument("--display", help="human-friendly policy name")
    p.add_argument("--namespace", default="tyk")
    p.add_argument("--api", action="append", required=True,
                   help="API CRD name to grant (repeat for base + each version child)")
    p.add_argument("--rate", type=int); p.add_argument("--per", type=int)
    p.add_argument("--quota", type=int); p.add_argument("--quota-renewal", type=int)
    a = p.parse_args()
    if len(a.api) == 1:
        sys.stderr.write("note: only one API granted. For a versioned API, also pass the "
                         "child version CRD(s) with --api, or keys will 403 on those versions.\n")
    sys.stdout.write(yaml_policy(a))

if __name__ == "__main__":
    main()
