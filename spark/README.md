# `spark/` — Spark performance pathologies (Phase 1) ✅ complete

The bread-and-butter failures every data engineer hits. Each module follows the
**Break → Detect → Fix → Prove** pattern (see [`docs/CURRICULUM_BRIEF.md`](../docs/CURRICULUM_BRIEF.md)),
reuses the [`common/`](../common/) toolkit, and ends with a teardown step.

> **Laptop safety:** every "break it" exercise is bounded and reversible — generated data is
> never stored, streams auto-stop, and `make clean` recovers. The memory-OOM module (`SPK-2`)
> uses the constrained box (`make up-constrained`); the rest run on the default tuned box.
>
> **Run any module:** `make up` → `make jupyter` → open its notebook, and watch the Spark UI at
> http://localhost:4040. All notebooks connect via Spark Connect and use only Connect-safe APIs.

## Modules

`[ ]` not started · `[~]` in progress · `[x]` built & live-tested (headless `nbconvert`)

| ID | Module | Status |
|----|--------|--------|
| `SPK-1` ⭐ | [Data / partition skew](spk1_data_skew.ipynb) — one key holds 90% of rows → one straggler task | `[x]` flagship |
| `SPK-2` | [Executor OOM](spk2_executor_oom.ipynb) — over-cache + too-few partitions → GC thrash / OOM *(needs `make up-constrained`)* | `[x]` |
| `SPK-3` | [Driver OOM](spk3_driver_oom.ipynb) — `.collect()`/`.toPandas()` on a generated-large frame | `[x]` |
| `SPK-4` | [Disk spill](spk4_disk_spill.ipynb) — too-few shuffle partitions → memory/disk spill | `[x]` |
| `SPK-5` | [Join strategies](spk5_join_strategies.ipynb) — broadcast vs sort-merge vs shuffle-hash | `[x]` |
| `SPK-6` | [AQE deep-dive](spk6_aqe.ipynb) — coalesce, skew-join split, runtime re-optimization | `[x]` |
| `SPK-7` | [Partition pruning & pushdown](spk7_partition_pruning.ipynb) — a `CAST`/UDF on the partition col kills pruning | `[x]` |
| `SPK-8` | [Caching & persistence](spk8_caching.ipynb) — storage levels, lazy cache, eviction, `unpersist` | `[x]` |
| `SPK-9` | [Shuffle internals & stages](spk9_shuffle.ipynb) — narrow vs wide, the partition-count sweep | `[x]` |
| `SPK-10` | [Deep internals sampler](spk10_internals.ipynb) — codegen, Catalyst, Tungsten, Kryo, speculation | `[x]` |

## Layout

Flat — one `spk<N>_<topic>.ipynb` per module (paths in the table above). `adhoc/` holds throwaway
scratch notebooks (not part of the curriculum). Modules are **built and statically validated**
(valid notebooks, all code cells compile, Connect-safe); run them against `make up` to see the
live before/after metrics.

## Suggested order

`SPK-1` (skew) → `SPK-9` (shuffle, the mechanism underneath) → `SPK-4` (spill) → `SPK-5` (joins)
→ `SPK-6` (AQE ties them together) → `SPK-2`/`SPK-3` (OOM) → `SPK-7` (pruning) → `SPK-8` (caching)
→ `SPK-10` (deep internals). Or jump straight to whatever just broke in your job.
