# lakehouse-lab — Curriculum Plan (Phased Roadmap)

> The **how / when / module-by-module** companion to [`CURRICULUM_BRIEF.md`](./CURRICULUM_BRIEF.md).
> Read the brief first (mission, the core "small-scale simulation" trick, the
> Break→Detect→Fix→Prove pattern, guardrails). This document is the execution roadmap plus a
> per-tool deep-topic inventory.

---

## How to use this plan

- Work is organized into **Phases** (0–7). Each phase is a self-contained track folder.
- Inside a phase are **Modules**, each addressable by ID (e.g. `SPK-1`, `CDC-3`).
- You can say **"do Phase 1"**, **"do module SPK-1"**, or **"do SPK-1 through SPK-3"** and I'll build
  exactly that, then stop for review.
- **Recommended order:** Phase 0 → Phase 1 (skew flagship first, then verify) → expand outward.
  Tracks are otherwise independent, so reorder to taste.
- Every module ships as: a runnable notebook (or DAG / dbt model / connector config) in its track
  folder, a short README following Break→Detect→Fix→Prove, and reuse of the shared `common/` toolkit.

### Module status legend
`[ ]` not started · `[~]` in progress · `[x]` done

---

# PHASE 0 — Foundation, toolkit & hygiene  *(do first)*

Builds the shared machinery every later module depends on, plus repo cleanup. **No teaching content
yet** — this is the scaffolding that makes the "break it safely & measure it" loop possible.

*Module list moved to [`LEARNING_PATH.md`](LEARNING_PATH.md) — see the phase table there for IDs, time estimates, and cross-links. Track READMEs (`spark/README.md`, `iceberg/README.md`, `kafka/README.md`, `debezium/README.md`) carry the per-module status checkboxes.*

**Phase 0 exit check:** a learner can flip to the constrained profile, generate skewed data,
run a job, and read a before/after metrics table — all without freezing their laptop.

---

# PHASE 1 — Spark performance pathologies  *(flagship track)*

The bread-and-butter failures every data engineer hits. **`SPK-1` (skew) is the flagship** —
build it first, verify the whole framework, checkpoint with the owner, then continue.

*Module list moved to [`LEARNING_PATH.md`](LEARNING_PATH.md) — see the phase table there for IDs, time estimates, and cross-links. Track READMEs (`spark/README.md`, `iceberg/README.md`, `kafka/README.md`, `debezium/README.md`) carry the per-module status checkboxes.*

---

# PHASE 2 — Lakehouse & table-format correctness (Iceberg / Delta / Parquet)

Open-table-format internals and the maintenance debt that bites in production.

*Module list moved to [`LEARNING_PATH.md`](LEARNING_PATH.md) — see the phase table there for IDs, time estimates, and cross-links. Track READMEs (`spark/README.md`, `iceberg/README.md`, `kafka/README.md`, `debezium/README.md`) carry the per-module status checkboxes.*

---

# PHASE 2.5 — Modern catalogs (Nessie, Polaris) + S3 & UIs  *(new)*

Iceberg-native REST catalogs replace the Hadoop-catalog anti-pattern used in Phase 2, and MiniStack
gives us S3-backed storage without a cloud account. Nimtable browses tables; StackPort browses raw S3
objects; both round out the Break→Detect→Fix→Prove pattern with visual confirmation of what really
landed on disk.

**Prerequisites:** `make up` (MiniStack ships in the default profile), then `make catalogs-up` to
add Nessie + Polaris + Nimtable, and optionally `make stackport-up` for the S3 visual browser.

*Module list moved to [`LEARNING_PATH.md`](LEARNING_PATH.md) — see the phase table there for IDs, time estimates, and cross-links. Track READMEs (`spark/README.md`, `iceberg/README.md`, `kafka/README.md`, `debezium/README.md`) carry the per-module status checkboxes.*

**Phase 2.5 exit check:** `make up && make catalogs-up`, create a table on Nessie's `dev` branch,
browse it in Nimtable, MERGE to `main`, cross-check the same snapshot IDs from Spark and Nimtable
(Nessie's `/iceberg/` REST surface). Laptop still responsive.

**Resolved during PLAN_V2** — both prior follow-ups landed:
- **Nessie writes** work end-to-end: `nessie_catalog` switched to `NessieCatalog` native (`/api/v2`)
  + `nessie-spark-extensions-4.0_2.13:0.108.0`, unlocking SQL `CREATE BRANCH` / `USE REFERENCE` /
  `MERGE BRANCH`. Table CREATE + INSERT verified on `dev` and `main`.
- **Polaris → Nimtable** browsing works: Nimtable now talks to Polaris via `/api/catalog` with the
  right credential + scope. **Polaris write remains STS-blocked on MiniStack Community** (Pro-tier
  unlock); CAT-5's governed marts land on `glue_catalog` instead. Full explanation in the matrix's
  footnote [F] ([`CATALOG_FORMAT_MATRIX.md`](./CATALOG_FORMAT_MATRIX.md)).

---

# PHASE 2.6 — Hudi format & timeline  *(new)*

Hudi is the third mainstream table format. Different metadata model (`.hoodie/` timeline) from
Iceberg's manifest tree or Delta's `_delta_log/`, but the same production trade-offs
(write amplification, compaction, upsert cost). Bundled in the default image — no extra profile.

*Module list moved to [`LEARNING_PATH.md`](LEARNING_PATH.md) — see the phase table there for IDs, time estimates, and cross-links. Track READMEs (`spark/README.md`, `iceberg/README.md`, `kafka/README.md`, `debezium/README.md`) carry the per-module status checkboxes.*

**Phase 2.6 exit check:** LAK-11 prints `parquet_files_on_disk: 1 → 2` for a 1-row MERGE on a 3-row
table (a stale slice is left behind — Hudi's CoW write amplification). The read still returns 3
rows with the mutated row's status changed.

---

# PHASE 3 — Kafka & Structured Streaming robustness

Messaging fundamentals + streaming correctness.

*Module list moved to [`LEARNING_PATH.md`](LEARNING_PATH.md) — see the phase table there for IDs, time estimates, and cross-links. Track READMEs (`spark/README.md`, `iceberg/README.md`, `kafka/README.md`, `debezium/README.md`) carry the per-module status checkboxes.*

---

# PHASE 4 — Debezium CDC track  *(new)*

Self-contained: **Postgres → Debezium (Kafka Connect) → Kafka → Spark Structured Streaming → Iceberg MERGE.**
Lives in `debezium/` with its own compose additions (Postgres + Kafka Connect), connector configs, and notebooks.

*Module list moved to [`LEARNING_PATH.md`](LEARNING_PATH.md) — see the phase table there for IDs, time estimates, and cross-links. Track READMEs (`spark/README.md`, `iceberg/README.md`, `kafka/README.md`, `debezium/README.md`) carry the per-module status checkboxes.*

---

# PHASE 5 — dbt advanced & data quality (dbt tests + Great Expectations)

Expands the existing dbt project well beyond the two demo models. Data-quality labs live in `dbt/quality/`.

*Module list moved to [`LEARNING_PATH.md`](LEARNING_PATH.md) — see the phase table there for IDs, time estimates, and cross-links. Track READMEs (`spark/README.md`, `iceberg/README.md`, `kafka/README.md`, `debezium/README.md`) carry the per-module status checkboxes.*

---

# PHASE 6 — Airflow orchestration challenges  *(generic, local-runnable DAGs)*

Replace the internal `prodrat_main` DAG with teaching DAGs in `airflow/dags/` that orchestrate the
repo's own Spark/dbt jobs. Each DAG demonstrates one production concept and runs fully locally.

*Module list moved to [`LEARNING_PATH.md`](LEARNING_PATH.md) — see the phase table there for IDs, time estimates, and cross-links. Track READMEs (`spark/README.md`, `iceberg/README.md`, `kafka/README.md`, `debezium/README.md`) carry the per-module status checkboxes.*

---

# PHASE 7 — Capstone: end-to-end pipeline, incident simulator & observability

*Module list moved to [`LEARNING_PATH.md`](LEARNING_PATH.md) — see the phase table there for IDs, time estimates, and cross-links. Track READMEs (`spark/README.md`, `iceberg/README.md`, `kafka/README.md`, `debezium/README.md`) carry the per-module status checkboxes.*

---

# Per-tool deep-topic inventory (knowledge map)

Condensed from research, organized must-know / good-to-have / niche-deep. This is the *content
backlog* the modules above draw from — useful when fleshing out or extending any module.

## Spark
- **Must:** data/partition skew; executor OOM; driver OOM; disk spill; join strategy selection; GC pauses.
- **Good:** shuffle internals & stage boundaries; AQE (coalesce/skew-join/reoptimize); partition pruning & predicate pushdown; caching/persistence levels & eviction; broadcast-variable misuse; serialization (Kryo vs Java); Catalyst optimizer basics; dynamic-partition-overwrite pitfalls.
- **Niche/Deep:** unified (Tungsten) memory model & `memory.fraction`; WholeStageCodegen; columnar/Arrow execution; Exchange operator internals; bloom-filter joins; speculative execution; external sort/spill protocol; task locality; RDD lineage & checkpointing.

## Iceberg / Delta / Parquet
- **Must:** small files & compaction (`rewrite_data_files` / `OPTIMIZE`); snapshot growth & `expire_snapshots`; orphan files & GC; manifest explosion & `rewrite_manifests`; streaming-write metadata thrash.
- **Good:** CoW vs MoR MERGE semantics; partition evolution; hidden partitioning; time travel & rollback; metadata caching/staleness; data-file lifecycle/GC; complex-predicate pruning failures.
- **Niche/Deep:** manifest column stats; format v1 vs v2 delete files; partition-spec versioning; metadata pointer/version-hint; catalog implementations (Hadoop/Hive/REST/Nessie); branch-based commits; Z-order/clustering; streaming checkpoint↔snapshot exactly-once.

## Kafka
- **Must:** partitioning & key choice / hot partitions; consumer groups & rebalancing; consumer lag & offset commit semantics; retention & log compaction; replication factor & ISR; exactly-once (idempotent producer + transactions + idempotent sink); schema evolution/compatibility; poison-pill/dead-letter.
- **Good:** fetch tuning (throughput vs latency); monitoring metrics & alerts; per-partition vs global ordering.
- **Niche/Deep:** transactional guarantees in Kafka Connect sinks; static membership; cooperative rebalancing.

## Debezium / CDC
- **Must:** snapshot vs streaming phases; logical replication slots & **WAL/disk growth**; CDC event envelope (before/after/op/ts); tombstones & delete handling; logical decoding & slot LSN; schema/DDL evolution; replica identity (capturing old values); at-least-once + idempotent sinks; the full Postgres→Debezium→Kafka→Spark→Iceberg pipeline & its failure modes.
- **Good:** connector restart & offset recovery; updates-as-upserts (MERGE) into Iceberg.
- **Niche/Deep:** Debezium Server vs Kafka Connect; WAL-retention tuning (`max_slot_wal_keep_size`); out-of-order delivery handling; ad-hoc/incremental snapshots (signals).

## dbt
- **Must:** materializations & full-refresh cost; incremental strategies (merge/insert_overwrite/append) + `unique_key`; late-arriving data & lookback windows; snapshots/SCD2; testing strategy & layering; `on_schema_change`; quarantine (`severity: warn`).
- **Good:** sources & freshness; model contracts/constraints; dbt-utils & dbt-expectations; Great Expectations integration & when to use which; exposures, docs/lineage; environments/targets & env-var config; packages.
- **Niche/Deep:** macros/Jinja patterns & `execute` phase; surrogate keys; slim CI (`--state`/`state:modified+`) & deferral; hooks (pre/post/on-run-end); Spark/Iceberg-specific gotchas (Thrift classloader on schema change, catalog split, partition-scoped MERGE).

## Airflow
- **Must:** idempotency & deterministic tasks; data-interval model (vs `now()`); catchup & backfills; retries/backoff/SLA; sensor modes (poke/reschedule/deferrable); trigger rules; TaskGroups; dynamic task mapping; XCom & size limits; connections/variables/secrets; branching/short-circuit; scheduling/timezones; Assets/Datasets (AF3); AF3 changes & Task SDK.
- **Good:** deferrable operators & triggers; testing DAGs; antipatterns (top-level code/heavy parsing); custom hooks; partitioned idempotent loads; pools/resource limits; monitoring & callbacks.
- **Niche/Deep:** custom triggers; HA triggerer; custom executors/queues/priority; Astronomer Cosmos for dbt; event-driven scheduling/REST API; custom XCom backends (object storage); advanced backfill strategies.

---

## Suggested build sequence (default)

1. **Phase 0** (`F-0`→`F-7`) — scaffolding + cleanup.
2. **`SPK-1`** — flagship skew module; **stop & review with owner**.
3. Rest of **Phase 1** (Spark) → **Phase 2** (Iceberg).
4. **Phase 3** (Kafka/Streaming) → **Phase 4** (Debezium CDC).
5. **Phase 5** (dbt + quality) → **Phase 6** (Airflow).
6. **Phase 7** capstone (incident simulator + e2e + observability).

> Tell me which phase or module IDs to build next, and I'll implement them one batch at a time,
> keeping the repo runnable and checking in for review at each checkpoint.
