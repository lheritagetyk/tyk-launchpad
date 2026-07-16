#!/usr/bin/env python3
# Build request bodies for the Tyk Enterprise Developer Portal API (products, plans,
# catalogues), matching the official swagger examples in
# vendor/tyk-docs/swagger/enterprise-developer-portal-swagger.yaml.
# Original code — emits JSON to stdout for lib/portal-api.sh to POST.
#
#   portal-payload.py product  --name payment_api --display "ACME Payment API" \
#       --provider 1 --api-id <APIID> [--oas-url URL] [--catalogue 1] [--dcr]
#   portal-payload.py plan     --name Bronze --provider 1 --rate 100 --per 60 \
#       --quota 10000 --quota-renewal 3600 [--auto-approve]
#   portal-payload.py catalogue --name "Public" [--product 1 ...] [--plan 1 ...]
import argparse, json, sys

def product(a):
    api = {"APIID": a.api_id}
    if a.description: api["Description"] = a.description
    if a.oas_url:     api["OASUrl"] = a.oas_url
    body = {
        "Name": a.name,
        "DisplayName": a.display or a.name,
        "ProviderID": a.provider,
        "APIDetails": [api],
        "IsDocumentationOnly": False,
        "DCREnabled": bool(a.dcr),
    }
    if a.content:    body["Content"] = a.content
    if a.catalogue:  body["Catalogues"] = a.catalogue
    if a.scopes:     body["Scopes"] = a.scopes
    return body

def plan(a):
    body = {"Name": a.name, "ProviderID": a.provider}
    if a.display:       body["DisplayName"] = a.display
    if a.description:   body["Description"] = a.description
    if a.rate is not None:          body["RateLimit"] = a.rate
    if a.per is not None:           body["Per"] = a.per
    if a.quota is not None:         body["Quota"] = a.quota
    if a.quota_renewal is not None: body["QuotaRenewalRate"] = a.quota_renewal
    if a.key_expires is not None:   body["KeyExpiresIn"] = a.key_expires
    if a.auto_approve:              body["AutoApproveAccessRequests"] = True
    if a.unlimited_quota:           body["UnlimitedQuota"] = True
    if a.unlimited_rate:            body["UnlimitedRateLimit"] = True
    if a.catalogue:                 body["Catalogues"] = a.catalogue
    return body

def catalogue(a):
    body = {"Name": a.name}
    if a.product: body["Products"] = a.product
    if a.plan:    body["Plans"] = a.plan
    return body

def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="kind", required=True)

    pp = sub.add_parser("product")
    pp.add_argument("--name", required=True); pp.add_argument("--display")
    pp.add_argument("--provider", type=int, required=True)
    pp.add_argument("--api-id", required=True); pp.add_argument("--oas-url")
    pp.add_argument("--description"); pp.add_argument("--content")
    pp.add_argument("--scopes"); pp.add_argument("--dcr", action="store_true")
    pp.add_argument("--catalogue", type=int, action="append")

    pl = sub.add_parser("plan")
    pl.add_argument("--name", required=True); pl.add_argument("--display")
    pl.add_argument("--provider", type=int, required=True)
    pl.add_argument("--description")
    pl.add_argument("--rate", type=float); pl.add_argument("--per", type=float)
    pl.add_argument("--quota", type=int); pl.add_argument("--quota-renewal", type=int)
    pl.add_argument("--key-expires", type=int)
    pl.add_argument("--auto-approve", action="store_true")
    pl.add_argument("--unlimited-quota", action="store_true")
    pl.add_argument("--unlimited-rate", action="store_true")
    pl.add_argument("--catalogue", type=int, action="append")

    pc = sub.add_parser("catalogue")
    pc.add_argument("--name", required=True)
    pc.add_argument("--product", type=int, action="append")
    pc.add_argument("--plan", type=int, action="append")

    a = p.parse_args()
    body = {"product": product, "plan": plan, "catalogue": catalogue}[a.kind](a)
    json.dump(body, sys.stdout, indent=2); sys.stdout.write("\n")

if __name__ == "__main__":
    main()
