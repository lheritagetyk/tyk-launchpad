#!/usr/bin/env python3
# Turn a Tyk OAS API into a versioning BASE API (or add a child to an existing base),
# per the official model: x-tyk-api-gateway.info.versioning with a versions[] list of
# {id, name}. See vendor/tyk-docs/api-management/api-versioning.mdx.
# Original code — edits the base OAS JSON; child API definitions are untouched.
#
# Usage:
#   set-versioning.py --base base.oas.json --child-id <API_ID> --version-name v2 \
#       [--key x-api-version] [--location header|url-param|url] [--default v1] > base.updated.json
import argparse, json, sys

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--base", required=True, help="path to the base API's Tyk OAS json")
    p.add_argument("--child-id", required=True, help="child API Id (x-tyk-api-gateway.info.id / CRD status.id)")
    p.add_argument("--version-name", required=True, help="label for the child version, e.g. v2")
    p.add_argument("--key", default="x-api-version", help="version identifier key (default x-api-version)")
    p.add_argument("--location", default="header",
                   choices=["header", "url-param", "url"], help="where the version id is read from")
    p.add_argument("--default", dest="default", default=None,
                   help="default version name; 'self' or the base's own name keeps base as default")
    a = p.parse_args()

    d = json.load(open(a.base))
    info = d.setdefault("x-tyk-api-gateway", {}).setdefault("info", {})
    base_name = info.get("name", "base")
    v = info.setdefault("versioning", {})

    # sensible defaults on first enable; preserve anything already set
    v.setdefault("enabled", True)
    v.setdefault("name", v.get("name", "v1"))          # the base's own version label
    v.setdefault("default", a.default or v["name"])    # base stays default unless told otherwise
    v.setdefault("fallbackToDefault", True)
    v.setdefault("stripVersioningData", False)
    v.setdefault("urlVersioningPattern", "")
    v["key"] = a.key
    v["location"] = a.location
    if a.default:
        v["default"] = a.default

    versions = v.setdefault("versions", [])
    # upsert the child by name
    versions[:] = [x for x in versions if x.get("name") != a.version_name]
    versions.append({"id": a.child_id, "name": a.version_name})

    # base must be External to receive/route client traffic
    info.setdefault("state", {})["internal"] = False

    json.dump(d, sys.stdout, indent=2)
    sys.stdout.write("\n")
    sys.stderr.write(f"base '{base_name}' now versions -> {[x['name'] for x in versions]} "
                     f"(key={a.key} location={a.location} default={v['default']})\n")

if __name__ == "__main__":
    main()
