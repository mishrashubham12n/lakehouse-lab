# Spark — Unified Server (Thrift + Connect) + History

**What it is:** Apache Spark 4.0.x built into a single JVM that exposes both Spark Connect (gRPC) and Thrift (HiveServer2) simultaneously, so notebooks (Connect) and dbt (Thrift) share one SparkContext. Includes Iceberg + Delta + Hudi runtime + hadoop-aws for `s3a://`.

**Managed by:** `make up` / `make down` (see `make/base.mk`).

## Ports

| Port  | What              |
|-------|-------------------|
| 15002 | Spark Connect (gRPC) |
| 10000 | Spark Thrift (dbt) |
| 4040  | Spark UI          |
| 18080 | History Server    |

## Resource profile

Flipped by `make up` (tuned) vs `make up-constrained` (constrained for OOM/spill modules).
Values live in `conf/profiles/{tuned,constrained}.env` — single source of truth.

## State

Spark UI event logs — `./.tmp/spark-events/` (wiped by `make clean`). No local warehouse dirs — all table data goes to `s3a://warehouse/` via MiniStack.

## How to interact

```bash
# Spark Connect from Python
from common.spark_session import spark
spark.sql("SHOW CATALOGS").show()

# dbt via Thrift
make dbt-build

# Beeline (from container shell)
docker compose exec spark-connect \
  /opt/spark/bin/beeline -u jdbc:hive2://localhost:10000
```

## Gotchas

- Do NOT edit `spark-defaults.conf` at runtime — bounce spark-connect (`make restart`) so JAR + config changes take effect.
- Thrift's classloader is the reason JARs live in `/opt/spark/jars/` (baked into the image) rather than `spark.jars.packages` (Ivy-resolved at runtime — Thrift can't see them).
- Warehouse paths must be `s3a://` — `MiniStack` must be healthy before `spark-connect` starts (enforced via `depends_on`).
