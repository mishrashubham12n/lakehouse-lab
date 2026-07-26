# StackPort — AWS Resource Browser UI

**What it is:** Universal AWS resource browser. Points at any AWS-compatible endpoint (real AWS, MiniStack, LocalStack, moto) and shows every service in one dashboard. In lakehouse-lab it fronts MiniStack.

**Managed by:** `make stackport-up` / `make stackport-down` (profile: `explorer`, opt-in).

## Port

| Port | What         |
|------|--------------|
| 8082 | Web UI (host) |

## What you can browse

- **S3** — list buckets, click into `warehouse/iceberg/…`, drill down into `metadata/`, `data/`, download individual `metadata.json` / `.avro` / `.parquet` files
- **Glue** — list databases and tables (when curriculum modules start using Glue as a catalog)
- **IAM** — roles, policies (when we teach RBAC via IAM)
- **STS, Lambda, DynamoDB, ...** — as MiniStack's `SERVICES` env var grows

## How to interact

```bash
make stackport-up
open http://localhost:8082
```

Login is not required — fake credentials `test/test` are baked in via env vars.

## Curriculum touchpoints

- **LAK-1 through LAK-10** — after every "Prove it" cell, students can open StackPort and see the actual metadata files their Spark writes produced. Complements Nimtable (which shows Iceberg *logical* structure); StackPort shows the *physical* file layout.
- **LAK-11 (Hudi)** — browse `s3a://warehouse/hudi/…` to see `.hoodie/` timeline files, base Parquet files, and log files.

## Gotchas

- **Uses port 8082** (not 8080) — 8080 is already Kafka UI. If you're stopping Kafka UI to save memory you can flip StackPort back to 8080 via `STACKPORT_PORT=8080 make stackport-up`.
- **Read-only for teaching** — StackPort can upload/delete objects too, which is fine for local MiniStack but a footgun on real AWS. Don't point it at production.
- **Not a replacement for AWS CLI** — real-world workflows use the CLI. StackPort is for exploration / teaching, not automation.
