# `iceberg/` — Lakehouse & table-format correctness (Phase 2) ✅ complete

Open-table-format internals (Iceberg / Delta / Parquet) and the **maintenance debt** that bites in
production. Each module follows **Break → Detect → Fix → Prove** (see
[`docs/CURRICULUM_BRIEF.md`](../docs/CURRICULUM_BRIEF.md)), reuses the [`common/`](../common/) toolkit
— including [`common/table_meta.py`](../common/table_meta.py) (`iceberg_table_health` /
`compare_health` for the LAK-* core, `hudi_table_health` + S3 helpers for the Hudi lessons) — and
ends with teardown.

> **Laptop-safe:** tiny data, all under `.tmp/`; `make clean` recovers. **Connect-safe:** every
> notebook uses `spark.sql` + DataFrame APIs only (Iceberg maintenance runs via
> `CALL iceberg_catalog.system.<proc>(...)`, which works over Spark Connect).
>
> **Run any module:** `make up` → `make jupyter` → open its notebook.

## Modules

`[ ]` not started · `[~]` in progress · `[x]` built & live-tested (headless `nbconvert`)

| ID | Module | Status |
|----|--------|--------|
| `LAK-1` | [Format comparison](lak1_format_comparison.ipynb) — Iceberg vs Delta vs Parquet (ACID, time travel, schema evo, MERGE) | `[x]` |
| `LAK-2` | [Small files & compaction](lak2_small_files.ipynb) — tiny-file litter → `rewrite_data_files` | `[x]` |
| `LAK-3` | [Snapshot growth & expiration](lak3_snapshots.ipynb) — unbounded snapshots → `expire_snapshots` | `[x]` |
| `LAK-4` | [Orphan files & GC](lak4_orphan_files.ipynb) — unreferenced files → `remove_orphan_files` (24h guard) | `[x]` |
| `LAK-5` | [Manifest explosion & rewrite](lak5_manifests.ipynb) — many manifests slow planning → `rewrite_manifests` | `[x]` |
| `LAK-6` | [Schema evolution](lak6_schema_evolution.ipynb) — add/rename/drop/widen by field-id vs positional Parquet | `[x]` |
| `LAK-7` | [Partitioning & hidden partitioning + evolution](lak7_partitioning.ipynb) — `days()`/`bucket()`, prune, evolve | `[x]` |
| `LAK-8` | [MERGE: CoW vs MoR](lak8_merge.ipynb) — 1-row MERGE rewrites a partition vs delete files | `[x]` |
| `LAK-9` | [Time travel & rollback](lak9_time_travel.ipynb) — recover a bad write; the expired-snapshot gotcha | `[x]` |
| `LAK-10` | [Deep format internals](lak10_internals.ipynb) — metadata pointer, manifest stats, v1/v2 deletes, catalogs | `[x]` |

## Phase 2.5 — Modern catalogs (opt-in, needs `make catalogs-up`)

Nessie / Polaris / Nimtable — Iceberg REST catalogs, RBAC, and Git-like branching over the same
data. Read [`docs/CATALOG_FORMAT_MATRIX.md`](../docs/CATALOG_FORMAT_MATRIX.md) first for the honest
what-works-where grid.

| ID | Module | Status |
|----|--------|--------|
| `CAT-1` | [Nessie intro](nessie/cat1_nessie_intro.ipynb) — Iceberg-REST semantics + Spark-vs-Nessie cross-check | `[x]` |
| `CAT-2` | [Polaris RBAC](cat2_polaris_rbac.ipynb) — principals, grants, the 403 body as a design | `[x]` |
| `CAT-3` | [Nessie SQL branching](nessie/cat3_branching.ipynb) — branch → write → merge/discard, all in SQL | `[x]` |
| `CAT-5` | [Cross-catalog federation](cat5_federation.ipynb) — one Spark job across `nessie_catalog` + `glue_catalog` | `[x]` |
| — | [`catalog_api_playground.ipynb`](catalog_api_playground.ipynb) | Raw REST plumbing for Nessie & Polaris (OAuth2, curl-equivalent calls) — reference, not a Break→Fix module |

## Phase 2.6 — Hudi (opt-in, ships in the base image)

Hudi CoW vs MoR write costs and the `.hoodie/` timeline internals. Companion to LAK-8 (Iceberg
MERGE): same operations across two formats, measured in **bytes** rather than file counts.

| ID | Module | Status |
|----|--------|--------|
| `LAK-11` | [Hudi intro](hudi/lak11_hudi_intro.ipynb) — read the `.hoodie/` timeline; CoW upserts via `MERGE`; write cost in bytes | `[x]` |
| `LAK-12` | [CoW vs MoR × Iceberg vs Hudi](hudi/lak12_cow_vs_mor.ipynb) — four-way write-amplification comparison | `[x]` |

## Layout

Flat — one `lak<N>_*.ipynb` / `cat<N>_*.ipynb` per module (paths in the tables above). Two
surviving folders: `hudi/` (LAK-11/12 + companion helpers) and `nessie/` (CAT-1 / CAT-3 +
Nessie-specific README).

## Suggested order

**Core (LAK-1..10):** `LAK-1` (formats) → `LAK-2` (small files) → `LAK-3` (snapshots) →
`LAK-5` (manifests) → `LAK-4` (orphans) → `LAK-6` (schema) → `LAK-7` (partitioning) →
`LAK-8` (MERGE) → `LAK-9` (time travel) → `LAK-10` (internals).

**Then catalogs:** `CAT-1` (Nessie REST) → `CAT-3` (branching) → `CAT-2` (Polaris RBAC) →
`CAT-5` (federation). Skim `catalog_api_playground.ipynb` any time you want the raw HTTP shape.

**Then Hudi:** `LAK-11` (Hudi timeline) → `LAK-12` (CoW vs MoR × Iceberg vs Hudi). Do LAK-8 first
so the comparison lands.
