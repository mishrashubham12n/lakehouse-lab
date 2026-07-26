# Learning Path — the production-challenges curriculum (CAP-4)

The master route through the whole curriculum: **60+ hands-on modules across 7 tracks + a capstone**
(10 Spark performance · 10 Iceberg/Delta/Parquet + 5 catalogs + 2 Hudi · 9 Kafka/streaming ·
9 Debezium/CDC · 10 dbt/quality · 10 Airflow · 4 capstone), each following
**Break → Detect → Fix → Prove**. You don't just run happy-path code — you break a real system at
small scale, watch it fail in the Spark UI / a dashboard, diagnose the root cause, fix it, and
**measure** the improvement.

How it stays laptop-safe: **generate, don't store** (synthesize billions of rows lazily with
`spark.range()` + `rand()`/`hash()`), **shrink the box, not the data** (a memory-capped container so
OOM/spill are real but the host stays usable), and **toggle the safety nets** (AQE / broadcast /
checkpoints on and off). See [`CURRICULUM_BRIEF.md`](CURRICULUM_BRIEF.md) for the philosophy and
[`CURRICULUM_PLAN.md`](CURRICULUM_PLAN.md) for the full module catalogue.

---

## Setup (once)

```bash
uv sync                 # Python deps (Spark Connect client, dbt-polyglot, GE, kafka-python, psycopg2)
make up                 # Spark 4.0.2 + Kafka + history + kafka-ui + MiniStack S3  (tuned ~3 GB profile)
make jupyter            # JupyterLab at :8888 — the notebook tracks (Spark, Iceberg, Kafka, CDC)
# opt-in, per track:
make catalogs-up        # + Nessie + Polaris + Nimtable (Phase 2.5 catalogs; ~1 GB)
make superset-up        # + Superset over Spark Thrift (all catalogs, all formats; opt-in browse UI)
make stackport-up       # + StackPort raw-S3 browser at :8082 (opt-in)
make cdc-up             # + Postgres + Kafka Connect (Phase 4 CDC; ~1.3 GB)
make airflow-up         # local Airflow 3 at :5000 (Phase 6 orchestration)
make monitoring-up      # + Prometheus + Grafana + kafka/postgres exporters (CAP-3 observability; ~1 GB)
cd dbt && source .env && dbt deps   # Phase 5 dbt packages
```

Dashboards: Spark UI http://localhost:4040 · History http://localhost:18080 · kafka-ui
http://localhost:8080 · Kafka Connect http://localhost:8083 · Airflow http://localhost:5000 ·
Nimtable http://localhost:8090 (admin/admin) · Superset http://localhost:8088 ·
Prometheus http://localhost:9090 · Grafana http://localhost:3000 (admin/admin) ·
StackPort (S3 browser) http://localhost:8082. Recover anytime with `make clean` (wipes both `.tmp/`
**and** the S3 warehouse); after that, `make nessie-reset` clears Nessie's ref graph so old table
pointers don't linger. For the OOM/spill modules use `make up-constrained` (~2 GB) so failure is
real but the laptop stays responsive.

Two reading guides sit alongside this path: [`spark-ui-guide.md`](spark-ui-guide.md) (symptom → which
UI tab/metric) and [`troubleshooting.md`](troubleshooting.md) (symptom → cause → fix cheat-sheet).

---

## Recommended order & what you can diagnose after each module

Times are rough hands-on estimates. Each module is self-contained; the **prereq** column is the
minimum concept you want first, not a hard gate.

### Phase 1 · `spark/` — performance pathologies  (start here)
Prereq: none. Run on `make up`; flip to `make up-constrained` for SPK-2/3/4.

| Module | min | After it you can diagnose… |
|--------|----:|----------------------------|
| [SPK-1 data skew](../spark/spk1_data_skew.ipynb) ⭐ | 25 | a straggler task doing 40× the median work; fix via AQE skew-join / salting |
| [SPK-2 executor OOM](../spark/spk2_executor_oom.ipynb) | 15 | container/executor OOM vs spill; partition sizing |
| [SPK-3 driver OOM](../spark/spk3_driver_oom.ipynb) | 15 | a `.collect()`/`toPandas()` that kills the driver (and the Connect session) |
| [SPK-4 disk spill](../spark/spk4_disk_spill.ipynb) | 15 | shuffle/aggregation spill in the Stages metrics |
| [SPK-5 join strategies](../spark/spk5_join_strategies.ipynb) | 20 | broadcast vs sort-merge vs shuffle-hash; why the planner chose wrong |
| [SPK-6 AQE deep-dive](../spark/spk6_aqe.ipynb) | 20 | what AQE rewrites at runtime (coalesce, skew, join switch) |
| [SPK-7 partition pruning & pushdown](../spark/spk7_partition_pruning.ipynb) | 15 | a full scan that should have pruned; predicate/projection pushdown |
| [SPK-8 caching & persistence](../spark/spk8_caching.ipynb) | 15 | recomputation vs cache; storage levels; when cache hurts |
| [SPK-9 shuffle internals & stages](../spark/spk9_shuffle.ipynb) | 20 | stage boundaries, shuffle read/write, partition counts |
| [SPK-10 deep internals](../spark/spk10_internals.ipynb) | 20 | Catalyst/AQE plan reading; the physical plan |

### Phase 2 · `iceberg/` — lakehouse / table-format correctness
Prereq: SPK-1 (reading the Spark UI). Run on `make up`.

| Module | min | After it you can diagnose… |
|--------|----:|----------------------------|
| [LAK-1 format comparison](../iceberg/lak1_format_comparison.ipynb) | 20 | Iceberg vs Delta vs Parquet (ACID, time travel, schema evo, MERGE) |
| [LAK-2 small files](../iceberg/lak2_small_files.ipynb) ⭐ | 20 | a table slow from thousands of tiny files; fix via `rewrite_data_files` |
| [LAK-3 snapshot growth](../iceberg/lak3_snapshots.ipynb) | 15 | unbounded snapshots; `expire_snapshots` |
| [LAK-4 orphan files & GC](../iceberg/lak4_orphan_files.ipynb) | 15 | unreferenced files; `remove_orphan_files` (24h guard) |
| [LAK-5 manifest explosion](../iceberg/lak5_manifests.ipynb) | 15 | slow planning from too many manifests; `rewrite_manifests` |
| [LAK-6 schema evolution](../iceberg/lak6_schema_evolution.ipynb) | 20 | add/rename/drop/widen by field-id vs positional Parquet |
| [LAK-7 partitioning & evolution](../iceberg/lak7_partitioning.ipynb) | 20 | hidden partitioning, pruning, partition-spec evolution |
| [LAK-8 MERGE: CoW vs MoR](../iceberg/lak8_merge.ipynb) | 20 | why a 1-row MERGE rewrites a whole partition |
| [LAK-9 time travel & rollback](../iceberg/lak9_time_travel.ipynb) | 15 | recover a bad write; the expired-snapshot gotcha |
| [LAK-10 deep internals](../iceberg/lak10_internals.ipynb) | 20 | metadata pointer, manifest stats, v1/v2 deletes |

### Phase 2.5 · `iceberg/` (catalogs) — modern catalogs (Nessie, Polaris, Glue)
Prereq: LAK-1 (Iceberg basics). Run `make up && make catalogs-up` (adds Nessie + Polaris + Nimtable);
optionally `make superset-up` for the universal browser and `make stackport-up` for raw-S3 view.
See [`CATALOG_FORMAT_MATRIX.md`](CATALOG_FORMAT_MATRIX.md) for the honest catalog × format grid.

| Module | min | After it you can diagnose… |
|--------|----:|----------------------------|
| [CAT-1 Iceberg on Nessie (REST catalog)](../iceberg/nessie/cat1_nessie_intro.ipynb) | 20 | same Iceberg snapshot from Spark and Nimtable — the "pointer owner" difference (Hadoop vs Nessie) |
| [CAT-2 Polaris + RBAC](../iceberg/cat2_polaris_rbac.ipynb) | 25 | a SELECT-only role rejecting a `DROP`; enterprise catalog governance; the STS write blocker on MiniStack |
| [CAT-3 Nessie branches](../iceberg/nessie/cat3_branching.ipynb) ⭐ | 25 | Git-for-data: `CREATE BRANCH dev`, mutate + isolate + `MERGE BRANCH dev INTO main` via the Nessie Spark SQL extension |
| [CAT-5 cross-catalog federation](../iceberg/cat5_federation.ipynb) | 20 | `INSERT INTO glue_catalog.marts.t SELECT * FROM nessie_catalog.staging.t` — two catalogs, one Spark session, governed marts |
| [Catalog API playground](../iceberg/catalog_api_playground.ipynb) | open-ended | control-plane REST/OAuth/RBAC/curl: Nessie refs, Polaris grants, Glue table admin (accompanies CAT-1..5) |

*CAT-4 (StackPort — see the physical files) was folded into the S3 browse steps of every CAT/LAK
notebook rather than shipping as its own module. See [`../services/stackport/README.md`](../services/stackport/README.md).*

### Phase 2.6 · `iceberg/` (Hudi) — Hudi format & timeline
Prereq: LAK-8 (MERGE / CoW vs MoR on Iceberg). Run on `make up`. Hudi 1.2.0 is baked into the default image.

| Module | min | After it you can diagnose… |
|--------|----:|----------------------------|
| [LAK-11 Hudi format & CoW upsert cost](../iceberg/hudi/lak11_hudi_intro.ipynb) | 20 | Hudi's `.hoodie/` timeline; a 1-row MERGE growing `parquet_files_on_disk` on a CoW table |
| [LAK-12 CoW vs MoR × Iceberg vs Hudi](../iceberg/hudi/lak12_cow_vs_mor.ipynb) ⭐ | 25 | the same 1-row upsert four ways, compared by bytes rewritten (the honest write-amplification proof) |

### Phase 3 · `kafka/` — Kafka & Structured Streaming robustness
Prereq: SPK-1. Run on `make up` (Kafka is part of the base stack).

| Module | min | After it you can diagnose… |
|--------|----:|----------------------------|
| [KAF-1 partitioning & hot partitions](../kafka/kaf1_partitioning.ipynb) ⭐ | 15 | one partition flooded by a dominant key; rekey/salt |
| [KAF-2 consumer lag & offsets](../kafka/kaf2_consumer_lag.ipynb) | 15 | lag = end − committed; auto vs manual commit; reprocess/loss |
| [KAF-3 rebalancing](../kafka/kaf3_rebalancing.ipynb) | 15 | rebalance storms; static membership / cooperative-sticky |
| [KAF-4 retention & compaction](../kafka/kaf4_retention.ipynb) | 15 | `OffsetOutOfRange` on a stale consumer; log compaction |
| [KAF-5 delivery semantics](../kafka/kaf5_delivery.ipynb) | 20 | at-least-once vs EOS; idempotent producer, `read_committed` |
| [KAF-6 poison pill / dead-letter](../kafka/kaf6_poison_pill.ipynb) | 15 | a corrupt record stalling a partition; dead-letter routing |
| [STR-1 watermarking & late data](../kafka/str1_watermarking.ipynb) | 20 | event vs processing time; a dropped-late-event |
| [STR-2 checkpoints & restart](../kafka/str2_checkpoints.ipynb) | 20 | resume-from-checkpoint; dedup on restart; exactly-once into Iceberg |
| [STR-3 backpressure](../kafka/str3_backpressure.ipynb) | 15 | `maxOffsetsPerTrigger`; the streaming small-files problem |

### Phase 4 · `debezium/` — Change Data Capture
Prereq: Phase 3 (Kafka), LAK-8 (MERGE). Run `make cdc-up` first.

| Module | min | After it you can diagnose… |
|--------|----:|----------------------------|
| [CDC-1 logical replication](../debezium/cdc1_logical_replication.ipynb) | 20 | `wal_level`, publications, replication slots |
| [CDC-2 connector bring-up](../debezium/cdc2_connector_bringup.ipynb) | 20 | registering Debezium via the Connect REST API; snapshot→stream |
| [CDC-3 snapshot modes](../debezium/cdc3_snapshot_modes.ipynb) | 15 | `snapshot.mode`; restart-from-scratch |
| [CDC-4 event envelope](../debezium/cdc4_event_envelope.ipynb) | 15 | before/after/op/ts; `ExtractNewRecordState` |
| [CDC-5 WAL/slot growth](../debezium/cdc5_wal_growth.ipynb) ⭐⚠️ | 20 | a slot pinning WAL → disk fills; `max_slot_wal_keep_size` |
| [CDC-6 deletes & replica identity](../debezium/cdc6_deletes.ipynb) | 15 | tombstones; `REPLICA IDENTITY FULL` |
| [CDC-7 Spark→Iceberg MERGE](../debezium/cdc7_upsert_pipeline.ipynb) ⭐ | 25 | building an idempotent (LSN-deduped) upsert mirror |
| [CDC-8 schema evolution](../debezium/cdc8_schema_evolution.ipynb) | 15 | DDL not in the stream; evolving the sink |
| [CDC-9 failure-mode tour](../debezium/cdc9_failure_modes.ipynb) | 20 | offset recovery, ordering, effectively-once reasoning |

### Phase 5 · `dbt/quality/` — dbt advanced & data quality
Prereq: SQL/dbt basics. Run `cd dbt && source .env && dbt deps` first.

| Module | min | After it you can diagnose… |
|--------|----:|----------------------------|
| [DBT-1 materializations](../dbt/quality/dbt1_materializations.md) | 15 | view/table/ephemeral/incremental cost tradeoffs |
| [DBT-2 incremental strategies](../dbt/quality/dbt2_incremental.md) ⭐ | 20 | merge vs insert_overwrite vs append; `unique_key` idempotency |
| [DBT-3 late-arriving & lookback](../dbt/quality/dbt3_late_arriving.md) ⭐ | 20 | rows silently dropped by a tight incremental window |
| [DBT-4 SCD2 snapshots](../dbt/quality/dbt4_snapshots_scd2.md) | 15 | `dbt_valid_from/to`; missed intraday changes |
| [DBT-5 schema-change](../dbt/quality/dbt5_schema_change.md) | 15 | `on_schema_change`; a column added/removed across runs |
| [DBT-6 testing & layering](../dbt/quality/dbt6_testing_strategy.md) | 15 | generic/singular/custom tests; `severity: warn` |
| [DBT-7 quarantine](../dbt/quality/dbt7_quarantine.md) | 15 | routing bad rows out instead of failing the build |
| [DBT-8 dbt-expectations + GE](../dbt/quality/dbt8_expectations_ge.md) | 20 | statistical/distribution checks; when dbt-tests vs GE |
| [DBT-9 sources/freshness/contracts](../dbt/quality/dbt9_sources_contracts.md) | 20 | a freshness SLA breach; an enforced contract |
| [DBT-10 macros & slim CI](../dbt/quality/dbt10_macros_slim_ci.md) | 20 | surrogate-key macros; `state:modified+` slim CI |

### Phase 6 · `airflow/` — orchestration
Prereq: AF-1→AF-3 give the data-interval foundation. Run `make airflow-up` (or `airflow dags test`).

| Module | min | After it you can diagnose… |
|--------|----:|----------------------------|
| [AF-1 idempotency](../airflow/dags/af1_idempotency.py) ⭐ | 15 | a re-run/backfill that double-writes |
| [AF-2 execution model](../airflow/dags/af2_execution_model.py) | 15 | `now()` antipattern vs the stable data interval |
| [AF-3 catchup/backfill](../airflow/dags/af3_catchup_backfill.py) | 15 | replaying history without collisions |
| [AF-4 retries/SLA](../airflow/dags/af4_retries_sla.py) | 15 | retry/backoff policy; deadline alerting |
| [AF-5 sensor modes](../airflow/dags/af5_sensor_modes.py) | 15 | poke vs reschedule vs deferrable; slot starvation |
| [AF-6 trigger rules/branching](../airflow/dags/af6_trigger_rules_branching.py) | 15 | a join skipped by the wrong trigger rule |
| [AF-7 dynamic mapping](../airflow/dags/af7_dynamic_mapping.py) | 15 | mapping over a runtime list; TaskGroups |
| [AF-8 XCom limits](../airflow/dags/af8_xcom_limits.py) | 10 | XCom bloat; pass URIs not payloads |
| [AF-9 assets/data-aware](../airflow/dags/af9_assets_data_aware.py) | 15 | producer→asset→consumer data-aware scheduling |
| [AF-10 dbt+Spark e2e](../airflow/dags/af10_dbt_spark_e2e.py) ⭐ | 20 | orchestrating real dbt/Spark/GE; Cosmos vs Bash; top-level-code |

### Phase 7 · `capstone/` — put it all together
Prereq: everything above (or at least the ⭐ flagships). `make up` + `make cdc-up`.

| Module | min | What it is |
|--------|----:|------------|
| [CAP-1 end-to-end pipeline](../capstone/) | 30 | one Airflow DAG: Postgres→Debezium→Kafka→Spark→Iceberg + dbt marts + quality gates + cleanup |
| [CAP-2 incident simulator](../capstone/incident_simulator/) ⭐ | open-ended | 8 on-call scenario cards — diagnose & fix like an SRE; the grand finale |
| [CAP-3 observability](OBSERVABILITY.md) *(opt-in)* | 15 | `make monitoring-up` → Prometheus + Grafana + `kafka-exporter` + `postgres-exporter` + Spark `PrometheusServlet`; the CDC-5 slot-growth and KAF-1/2 lag signals go live |
| CAP-4 learning path | — | this document |

---

## Routes through the curriculum

- **Full path (recommended):** Phase 1 → 2 → 2.5 → 2.6 → 3 → 4 → 5 → 6 → 7, in order. ~22–28 hours hands-on.
- **"I work on batch Spark":** Phase 1 (all) → Phase 2 → LAK-8/CDC-7 for MERGE → CAP-2 cards INC-1/2/3.
- **"I work on streaming":** SPK-1 → Phase 3 (all) → Phase 4 (CDC) → CAP-2 cards INC-4/5/8.
- **"I work on the warehouse / analytics engineering":** Phase 2 (LAK-1/2/6/8) → Phase 5 (all) →
  Phase 6 (AF-1/2/3/10) → CAP-2 cards INC-6/7.
- **"Lakehouse-format depth":** Phase 2 (LAK-1..10) → Phase 2.5 (CAT-1..5 + playground) →
  Phase 2.6 (LAK-11..12) — the honest catalog × format grid at
  [`CATALOG_FORMAT_MATRIX.md`](CATALOG_FORMAT_MATRIX.md) is the map for this route.
- **"On-call prep / interview drill":** skim each track's README, then go straight to
  [CAP-2 the incident simulator](../capstone/incident_simulator/) and diagnose cold.

Every flagship (⭐) is a good standalone session if you only have an hour.
