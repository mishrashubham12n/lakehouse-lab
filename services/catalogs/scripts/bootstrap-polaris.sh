#!/usr/bin/env bash
# =============================================================================
# Bootstrap the `lab` catalog in Polaris (schema + root principal are already
# created by the polaris-bootstrap sidecar). This script fetches an OAuth2
# access token as the root principal, then creates the `lab` catalog via the
# management API. Idempotent — a 409 (catalog already exists) is treated as ok.
# =============================================================================
set -euo pipefail

POLARIS_PORT="${POLARIS_PORT:-8181}"
POLARIS_MGMT_PORT="${POLARIS_MGMT_PORT:-8182}"
POLARIS_URL="http://localhost:${POLARIS_PORT}"
POLARIS_MGMT_URL="http://localhost:${POLARIS_MGMT_PORT}"
POLARIS_REALM="${POLARIS_REALM:-default}"
POLARIS_CLIENT_ID="${POLARIS_CLIENT_ID:-root}"
POLARIS_CLIENT_SECRET="${POLARIS_CLIENT_SECRET:-secret}"
POLARIS_CATALOG_NAME="${POLARIS_CATALOG_NAME:-lab}"
POLARIS_WAREHOUSE="${POLARIS_WAREHOUSE:-s3a://warehouse/polaris/}"
MINISTACK_INTERNAL_URL="${MINISTACK_INTERNAL_URL:-http://ministack:4566}"
MINISTACK_HOST_URL="${MINISTACK_HOST_URL:-http://localhost:4566}"
POLARIS_ROLE_ARN="${POLARIS_ROLE_ARN:-arn:aws:iam::000000000000:role/polaris-role}"

# ── Ensure MiniStack IAM has the polaris-role (idempotent) ────────────────
# Polaris configures its S3 storage with a roleArn and calls STS AssumeRole
# even with SKIP_CREDENTIAL_SUBSCOPING_INDIRECTION=true (the flag only skips
# the SECOND scoping call). Both AWS_ENDPOINT_URL_STS and this role must
# exist in MiniStack IAM or CREATE TABLE will fail.
echo "  Ensuring MiniStack IAM role 'polaris-role' exists..."
python3 - <<PY
import urllib.request, urllib.parse, json, sys
body = urllib.parse.urlencode({
    "Action": "CreateRole",
    "Version": "2010-05-08",
    "RoleName": "polaris-role",
    "AssumeRolePolicyDocument": json.dumps({
        "Version": "2012-10-17",
        "Statement": [{"Effect": "Allow",
                       "Principal": {"AWS": "*"},
                       "Action": "sts:AssumeRole"}],
    }),
}).encode()
req = urllib.request.Request(
    "${MINISTACK_HOST_URL}/",
    data=body, method="POST",
    headers={"Content-Type": "application/x-www-form-urlencoded; charset=utf-8",
             "Authorization": "AWS4-HMAC-SHA256 Credential=test/20260720/us-east-1/iam/aws4_request"},
)
try:
    urllib.request.urlopen(req, timeout=5)
    print("  IAM role 'polaris-role' created.")
except urllib.error.HTTPError as e:
    body = e.read().decode()
    if "EntityAlreadyExists" in body:
        print("  IAM role 'polaris-role' already exists.")
    else:
        print(f"  IAM role create returned HTTP {e.code}: {body[:200]}")
        sys.exit(1)
PY

# ── Wait for Polaris management endpoint ──────────────────────────────────
echo "  Waiting for Polaris /q/health..."
for i in $(seq 1 30); do
  if curl -sf "${POLARIS_MGMT_URL}/q/health" >/dev/null 2>&1; then
    echo "  Polaris healthy after $((i*2))s"
    break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then
    echo "  Polaris did not become healthy in 60s — aborting bootstrap"
    exit 1
  fi
done

# ── Fetch OAuth2 access token (client_credentials flow) ───────────────────
echo "  Fetching OAuth2 token (realm=${POLARIS_REALM})..."
token_response=$(curl -sS -X POST "${POLARIS_URL}/api/catalog/v1/oauth/tokens" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Polaris-Realm: ${POLARIS_REALM}" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=${POLARIS_CLIENT_ID}" \
  --data-urlencode "client_secret=${POLARIS_CLIENT_SECRET}" \
  --data-urlencode "scope=PRINCIPAL_ROLE:ALL")

TOKEN=$(printf '%s' "$token_response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))")
if [ -z "$TOKEN" ]; then
  echo "  Failed to obtain OAuth2 token. Response:"
  echo "  $token_response"
  exit 1
fi
echo "  Token OK (${#TOKEN} chars)"

# ── Create catalog (idempotent — 409 = already exists) ────────────────────
echo "  Creating Polaris catalog '${POLARIS_CATALOG_NAME}' (idempotent)..."
http_code=$(curl -sS -o /tmp/polaris-bootstrap-response \
  -w "%{http_code}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Polaris-Realm: ${POLARIS_REALM}" \
  -H "Content-Type: application/json" \
  -X POST "${POLARIS_URL}/api/management/v1/catalogs" \
  -d @- <<EOF
{
  "catalog": {
    "name": "${POLARIS_CATALOG_NAME}",
    "type": "INTERNAL",
    "properties": {
      "default-base-location": "${POLARIS_WAREHOUSE}"
    },
    "storageConfigInfo": {
      "storageType": "S3",
      "allowedLocations": ["${POLARIS_WAREHOUSE}"],
      "s3Endpoint": "${MINISTACK_INTERNAL_URL}",
      "s3PathStyleAccess": true,
      "s3Region": "us-east-1"
    }
  }
}
EOF
)

case "${http_code}" in
  200|201|204) echo "  Catalog '${POLARIS_CATALOG_NAME}' created" ;;
  409)         echo "  Catalog '${POLARIS_CATALOG_NAME}' already exists" ;;
  *)           echo "  Catalog bootstrap returned HTTP ${http_code}:"
               cat /tmp/polaris-bootstrap-response 2>/dev/null || true
               exit 1 ;;
esac
