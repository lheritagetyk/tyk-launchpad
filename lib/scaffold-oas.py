#!/usr/bin/env python3
# Scaffold a minimal, valid Tyk OAS API definition (with the x-tyk-api-gateway
# extension) from a few inputs. Original code — produces a generic skeleton the
# agent fills in; nothing is copied from Tyk-shipped files.
#
# Usage:
#   scaffold-oas.py --name "Petstore" --listen /petstore/ --upstream https://httpbin.org \
#                   [--auth-token] [--cors] > petstore.oas.json
import argparse, json, sys

def build(name, listen, upstream, auth_token, cors, internal=False, api_id=None):
    info = {"name": name, "state": {"active": True, "internal": internal}}
    if api_id:
        info["id"] = api_id          # user-defined API Id (for deterministic version links)
    xtyk = {
        "info": info,
        "upstream": {"url": upstream},
        "server": {"listenPath": {"value": listen, "strip": True}},
    }
    if auth_token:
        xtyk["server"]["authentication"] = {
            "enabled": True,
            "securitySchemes": {"authToken": {"enabled": True}},
        }
    if cors:
        # Official CORS location for Tyk OAS is middleware.global.cors.
        xtyk.setdefault("middleware", {}).setdefault("global", {})["cors"] = {
            "enabled": True,
            "allowedOrigins": ["*"],
            "allowedMethods": ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"],
            "allowedHeaders": ["Authorization", "Accept", "Content-Type", "Origin"],
            "exposedHeaders": [],
            "allowCredentials": False,
            "maxAge": 24,
            "optionsPassthrough": False,
            "debug": False,
        }
    return {
        "openapi": "3.0.3",
        "info": {"title": name, "version": "1.0.0"},
        "paths": {},
        "x-tyk-api-gateway": xtyk,
    }

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--name", required=True)
    p.add_argument("--listen", required=True, help="listen path, e.g. /petstore/")
    p.add_argument("--upstream", required=True, help="upstream URL")
    p.add_argument("--auth-token", action="store_true", help="require an auth token")
    p.add_argument("--cors", action="store_true", help="enable CORS (needed for portal Try-It)")
    p.add_argument("--internal", action="store_true", help="mark state.internal=true (for child versions)")
    p.add_argument("--id", dest="api_id", help="user-defined API Id (x-tyk-api-gateway.info.id)")
    a = p.parse_args()
    if not a.listen.startswith("/"):
        p.error("--listen must start with '/'")
    json.dump(build(a.name, a.listen, a.upstream, a.auth_token, a.cors, a.internal, a.api_id),
              sys.stdout, indent=2)
    sys.stdout.write("\n")

if __name__ == "__main__":
    main()
