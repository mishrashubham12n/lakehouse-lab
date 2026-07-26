#!/usr/bin/env bash
# =============================================================================
# Idempotently create the `warehouse` S3 bucket in MiniStack.
# Called by `make up` after ministack becomes healthy.
# =============================================================================
# Uses python (bundled in the ministack container) so we don't depend on curl
# or aws-cli being installed anywhere.
# =============================================================================
set -euo pipefail

# Run the PUT from inside the ministack container so it always resolves the
# right endpoint (works even if the host isn't set up with AWS credentials).
if docker compose exec -T ministack python -c "
import urllib.request, urllib.error, sys
req = urllib.request.Request('http://localhost:4566/warehouse', method='PUT')
try:
    urllib.request.urlopen(req, timeout=3)
    sys.exit(0)  # created
except urllib.error.HTTPError as e:
    # 409 = BucketAlreadyOwnedByYou / BucketAlreadyExists — success
    sys.exit(0 if e.code in (409, 200) else 1)
" 2>/dev/null; then
  echo "  MiniStack    : s3://warehouse ready"
else
  echo "  MiniStack    : s3://warehouse seed skipped (ministack not yet ready)"
fi
