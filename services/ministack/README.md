# MiniStack — Local AWS emulator (S3 + Glue + IAM)

**What it is:** MIT-licensed AWS emulator that replaces MinIO (archived Apr 2026). Runs S3, Glue, IAM, STS on a single port. Backs all `s3a://warehouse/` table storage in lakehouse-lab.

**Managed by:** `make up` (always-on, no profile).

## Port

| Port | What                              |
|------|-----------------------------------|
| 4566 | All AWS services multiplexed here |

## Credentials

Fake, hardcoded — do NOT copy this pattern to real AWS. Use test values everywhere:

```
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
```

## State

`./.tmp/ministack/` (bind mount) — buckets, IAM state. Wiped by `make clean`.

## How to interact — AWS CLI

Set a shell alias once:

```bash
alias aws-lab='aws --endpoint-url=http://localhost:4566'
```

Then everything AWS-native works:

```bash
# S3 — list buckets and browse the warehouse
aws-lab s3 ls
aws-lab s3 ls s3://warehouse/ --recursive
aws-lab s3 cp s3://warehouse/iceberg/default/lak2_events/metadata/v1.metadata.json -

# Glue — list databases and tables
aws-lab glue get-databases
aws-lab glue get-tables --database-name marts

# IAM — list roles/policies
aws-lab iam list-roles
```

## How to interact — visual UI

Start the `explorer` profile for a browser dashboard:

```bash
make stackport-up
open http://localhost:8082
```

StackPort browses S3 objects, Glue databases, IAM roles, all through MiniStack. See [services/stackport/README.md](../stackport/README.md).

## How to interact — Spark

Spark writes to MiniStack via `s3a://` — config is in `conf/spark-defaults.conf`:

```
spark.hadoop.fs.s3a.endpoint            http://ministack:4566   # container network
spark.hadoop.fs.s3a.access.key          test
spark.hadoop.fs.s3a.secret.key          test
spark.hadoop.fs.s3a.path.style.access   true
```

Every Iceberg / Delta / Hudi table lands under `s3a://warehouse/<format>/`.

## Gotchas

- **Path-style access is mandatory** — MiniStack doesn't do virtual-hosted-style URLs.
- **Credentials must be non-empty** — even fake ones. Empty `access_key` triggers AnonymousAWSCredentialsProvider issues in hadoop-aws.
- **`INIT_BUCKETS` bakes buckets at container start** — if you add a new one at runtime, it lives until the container is destroyed. `make clean` re-seeds from `INIT_BUCKETS`.
- **SERVICES env var trims the fleet** — if you want to teach a new AWS service (Lambda, Kinesis, DynamoDB), add it to `SERVICES=` in `compose.yml`. Each unused service saves ~30 MB.
