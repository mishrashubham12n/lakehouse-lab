# Hudi track — intro & write-mode trade-offs

Two hands-on lessons on Apache Hudi (the third major table format after
Iceberg and Delta). Narrative lives inside each notebook; this is just the
index.

| Lesson | Notebook | Teaches |
|---|---|---|
| **LAK-11** | [`lak11_hudi_intro.ipynb`](./lak11_hudi_intro.ipynb) | Hudi's `.hoodie/` **timeline** + copy-on-write upserts via `MERGE` — read the timeline directly, prove the write cost in bytes. |
| **LAK-12** | [`lak12_cow_vs_mor.ipynb`](./lak12_cow_vs_mor.ipynb) | **Copy-on-write vs merge-on-read** run four ways (Iceberg CoW/MoR × Hudi CoW/MoR) — the write-amplification trade measured in **bytes**. |

- **Run against:** `make up` (MiniStack + Spark Connect). Hudi ships in the default image; table data lands under `s3a://warehouse/hudi/…` (Iceberg comparisons under `s3a://warehouse/iceberg/…`).
- **Helpers:** `common.table_meta` (`table_health`, `wipe_prefix`, `s3_client`, `split_s3`) — thin S3 boilerplate; the Hudi technique (reading the timeline / listing base-vs-log files) is shown inline in the notebooks.
- **Related:** [LAK-8 — Iceberg MERGE (CoW/MoR)](../lak8_merge.ipynb).

> Run a lesson: `jupyter nbconvert --to notebook --execute iceberg/hudi/<lesson>.ipynb` with `PYTHONPATH=<repo-root>`, or open it in Jupyter.
