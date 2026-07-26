# =============================================================================
# Spark Unified Server (Thrift + Connect) + History Server
# Base: Apache Spark 4.0.2 (the variant available on Docker Hub as of July 2026;
#       4.0.3/4.0.4 are released upstream but not yet published as
#       spark:X-scala2.13-java17-python3-ubuntu images)
# =============================================================================
# Bundled runtimes:
#   - Iceberg 1.10.1        (spark4.0, scala2.13)
#   - Iceberg AWS bundle 1.10.1 (GlueCatalog + S3FileIO + STS — glue_catalog and
#                                the Nessie/Polaris REST catalogs' S3 data I/O)
#   - Nessie Spark ext 0.108.0  (spark4.0, scala2.13 — enables SQL BRANCH/USE
#                                REFERENCE/MERGE BRANCH DDL. Version pinned to
#                                match the Nessie SERVER in services/catalogs.
#                                Maven Central *does* publish the spark-4.0 build
#                                — the search API index is stale; maven-metadata
#                                is authoritative.)
#   - Delta 4.0.0           (spark4.0, scala2.13)
#   - Kafka connector 4.0.2 (matches Spark version)
#   - Hudi 1.2.0            (spark4.0, scala2.13) — only viable line for Spark 4.0.x
#   - hadoop-aws 3.4.1      (for s3a:// — MUST match hadoop-client-{api,runtime} shipped with Spark)
#   - PostgreSQL JDBC 42.7.3 (lets Spark read/write Postgres via JDBC —
#                             used by CDC lessons + dbt-spark→Postgres targets)
# =============================================================================

# ── Stage 1: Resolve JARs via Ivy (handles all transitive dependencies) ─────
FROM spark:4.0.2-scala2.13-java17-python3-ubuntu AS deps

ARG SPARK_PACKAGES="\
org.apache.iceberg:iceberg-spark-runtime-4.0_2.13:1.10.1,\
org.apache.iceberg:iceberg-aws-bundle:1.10.1,\
org.projectnessie.nessie-integrations:nessie-spark-extensions-4.0_2.13:0.108.0,\
io.delta:delta-spark_2.13:4.0.0,\
org.apache.spark:spark-sql-kafka-0-10_2.13:4.0.2,\
org.apache.hudi:hudi-spark4.0-bundle_2.13:1.2.0,\
org.apache.hadoop:hadoop-aws:3.4.1,\
org.postgresql:postgresql:42.7.3"

# Resolve into /tmp/ivy/jars. Show the tail (so any Ivy UNRESOLVED-dependency
# errors are visible in the build log) but decide pass/fail on whether jars were
# actually produced — a silent `2>/dev/null || true` here previously cached an
# EMPTY layer and broke the stage-2 `COPY --from=deps /tmp/ivy/jars/`.
RUN echo ':quit' | $SPARK_HOME/bin/spark-shell \
      --conf spark.jars.ivy=/tmp/ivy \
      --packages "${SPARK_PACKAGES}" 2>&1 | tail -n 50 || true; \
    test -n "$(ls -A /tmp/ivy/jars 2>/dev/null)" \
      || { echo 'FATAL: SPARK_PACKAGES resolution produced no jars — see coordinates above'; exit 1; }

# ── Stage 2: Final image ────────────────────────────────────────────────────
FROM spark:4.0.2-scala2.13-java17-python3-ubuntu

USER root

# System utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl procps netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

# uv — fast Python package manager
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Pre-resolved JARs from stage 1 → system classpath (fixes Thrift classloader)
COPY --from=deps /tmp/ivy/jars/ /opt/spark/jars/

WORKDIR /app

# Python dependencies (cached layer — only rebuilds when manifests change)
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen 2>/dev/null || uv sync

# Spark configuration
COPY conf/spark-defaults.conf /opt/spark/conf/spark-defaults.conf
COPY conf/log4j2.properties /opt/spark/conf/log4j2.properties

# Entrypoint
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create required directories — table data lives on s3a:// via MiniStack, so
# only local runtime dirs (event logs) are needed.
RUN mkdir -p .tmp/spark-events logs /opt/spark/logs

# Copy project files
COPY . .

# Ports: 10000=Thrift JDBC, 15002=Spark Connect, 4040=Spark UI, 18080=History
EXPOSE 10000 15002 4040 18080

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["connect"]
