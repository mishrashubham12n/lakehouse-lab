# Catalog × Format Matrix

> The honest grid of which table format works in which catalog on this stack, *and why the holes exist*. First-class content, not an apology. Read alongside [`CURRICULUM_PLAN.md`](./CURRICULUM_PLAN.md) (Phase 2.5 / 2.6) and [`PLAN_V2.md`](./PLAN_V2.md) §WS5/WS9.

## TL;DR

Five catalogs are wired in `conf/spark-defaults.conf` (`iceberg_catalog`, `spark_catalog`, `nessie_catalog`, `polaris_catalog`, `glue_catalog`); three formats ship in the default image (Iceberg 1.10.1, Delta 4.0.0, Hudi 1.2.0). Most cells are ✅; the holes are architectural (Iceberg-REST vs. Hive-metastore-family) and honestly documented — students hit them **knowingly**.

## 1. The matrix

Rows = catalogs. Columns = the three formats + the explorer(s) that can browse tables in that catalog.

| Catalog | Iceberg | Delta | Hudi | Explorer(s) |
|---|---|---|---|---|
| **`iceberg_catalog`** (Iceberg on Hadoop, S3) | ✅ [1] | ❌ [A] | ❌ [A] | Spark SQL `SHOW/DESCRIBE` + StackPort [E1] |
| **`spark_catalog`** (Delta on Spark's default) | ❌ [B] | ✅ [2] | ✅ [3] | Spark SQL + Superset + StackPort [E2] |
| **`nessie_catalog`** (Nessie native, Git-like branches) | ✅ [4] | ❌ [A] | ❌ [A] | Nimtable + Spark SQL + Superset + StackPort [E3] |
| **`polaris_catalog`** (Iceberg REST + RBAC) | ⚠️ [5] | ❌ [A] | ❌ [A] | Nimtable + Spark SQL + Superset + StackPort [E4] |
| **`glue_catalog`** (Iceberg on AWS Glue via MiniStack) | ✅ [6] | ❌ [C] | ❌ [C] | Spark SQL + Superset + StackPort [E5] |

**Legend:** ✅ works · ❌ blocked · ⚠️ partial (read yes, write no)

### Cell footnotes

**[1] `iceberg_catalog` + Iceberg — ✅**
Hadoop catalog on `s3a://warehouse/iceberg/`. Anti-pattern for concurrent writers (filesystem semantics on S3) — kept for the LAK-1..10 pedagogical arc that teaches *why* Iceberg needs a real catalog. Works for single-writer learning.

**[2] `spark_catalog` + Delta — ✅**
`DeltaCatalog` is registered as `spark_catalog`; warehouse `s3a://warehouse/delta/`. Native path.

**[3] `spark_catalog` + Hudi — ✅ (via `USING hudi` + LOCATION)**
Hudi doesn't get its own catalog entry (see [C]). The LAK-11/12 pattern is:
```sql
CREATE TABLE spark_catalog.<ns>.<name> (...) USING hudi
LOCATION 's3a://warehouse/hudi/<ns>/<name>/'
TBLPROPERTIES ('primaryKey'='…', 'preCombineField'='…', 'type'='cow');
```
`DeltaCatalog` delegates `USING hudi` DDL to Hudi's write path. Verified end-to-end.

**[4] `nessie_catalog` + Iceberg — ✅**
Runs `NessieCatalog` (native `/api/v2`), not the Iceberg-REST adapter (see [D]). Unlocks `CREATE BRANCH … IN nessie_catalog`, `USE REFERENCE`, `MERGE BRANCH` via the Nessie Spark SQL extension.

**[5] `polaris_catalog` + Iceberg — ⚠️ read/RBAC only**
Read + `SHOW`/`DESCRIBE` + RBAC (`CREATE ROLE`, `GRANT`, `LIST NAMESPACES`) all work — that's the CAT-2 lesson. **Write is blocked** in MiniStack Community: Polaris's storage-credential-vending path calls STS `AssumeRole`, MiniStack Community's STS emulator returns metadata Polaris's AWS SDK can't act on (see [F]). CAT-5's governed marts land on `glue_catalog` instead. Documented as Pro-tier.

**[6] `glue_catalog` + Iceberg — ✅**
`GlueCatalog` via the `iceberg-aws-bundle`, warehouse `s3a://warehouse/glue/`. **Static creds only** — deliberately no `client.assume-role.arn` (STS is the Polaris blocker; sidestepped here). Single-writer verified; concurrent-writer `UpdateTable` optimistic-lock behavior is a documented caveat. `DROP TABLE` in Iceberg on Glue **does not purge S3 data** (needs `PURGE` or `make clean`).

### Hole footnotes — *why*

**[A] Nessie / Polaris / Hadoop-catalog + Delta or Hudi — ❌ "foreign protocol"**
Nessie and Polaris speak the **Iceberg REST spec** (Polaris entirely; Nessie via `/iceberg/` on top of the native protocol). Delta's transaction log (`_delta_log/`) and Hudi's timeline (`.hoodie/`) are not part of that spec — the catalog has no "commit" or "manifest" concept for them. `iceberg_catalog` (Hadoop) is filesystem semantics, no metastore at all; likewise can't own a Delta or Hudi table. This is a **protocol boundary**, not a bug — teaching material, not a limitation to route around.

**[B] `spark_catalog` + Iceberg — ❌ "catalog ownership"**
`DeltaCatalog` claims `spark_catalog` (registered as its `SparkCatalog` impl). Iceberg tables live in their own catalogs (`iceberg_catalog`, `nessie_catalog`, `glue_catalog`, `polaris_catalog`). Not fatal — students can `USE iceberg_catalog` when they want Iceberg.

**[C] No `hudi_catalog` — "delegating-extension collision"**
`HoodieCatalog` is a `DelegatingCatalogExtension` — it's architecturally valid only when it **replaces** `spark_catalog` (it needs a session-catalog delegate). Registering it as a standalone secondary catalog fails with `NullPointerException: this.delegate is null` on any DDL. Since `DeltaCatalog` already owns `spark_catalog` in this stack, Hudi cannot coexist as its own catalog and instead rides through `spark_catalog` + `USING hudi` + `LOCATION` (LAK-11/12, cell [3]).

**[D] Why Nessie uses the native protocol, not `type=rest`**
The Nessie Spark SQL extension (`NessieSparkSessionExtensions`, source of `CREATE BRANCH` / `USE REFERENCE` / `MERGE BRANCH` DDL) is designed against the native `/api/v2` protocol. Against the Iceberg-REST adapter at `/iceberg/` it mis-encodes the branch prefix as `<ref><warehouse>` (missing the `|` separator) and writes fail. Nimtable browses Nessie via `/iceberg/` REST independently — both protocols read/write the **same commit graph**.

**[E] Explorer notes**
- **[E1]** No REST endpoint on the Hadoop catalog → no Nimtable. Spark SQL `SHOW/DESCRIBE` + StackPort's raw-S3 browse cover it.
- **[E2]** `spark_catalog` isn't REST → no Nimtable. Superset over Spark Thrift on `:10000` (WS9) sees every table here (Delta + Hudi).
- **[E3]** Nimtable browses Nessie via `/iceberg/`. Superset over Spark Thrift also sees it. Snapshot IDs agree across Spark ⇄ curl ⇄ Nimtable (CAT-1's three-way gate).
- **[E4]** Nimtable browses Polaris via `/api/catalog` (config carries `credential` + `scope`). Same Superset story.
- **[E5]** Glue has no Iceberg-REST surface → not browsable by Nimtable. Superset over Spark Thrift + StackPort's Glue database/table view + Spark SQL cover it.

**[F] Polaris write blocker — technical**
Polaris's storage-credential-vending path calls **STS AssumeRole**. MiniStack Community's STS emulator responds but returns metadata Polaris's AWS SDK can't act on — subsequent hostname resolution fails inside Docker (`UnknownHostException` on a virtual-host `bucket.s3.amazonaws.com` name). `POLARIS_FEATURES_SKIP_CREDENTIAL_SUBSCOPING_INDIRECTION=true` only skips the *secondary* subscoping call; the initial AssumeRole still fires. `FILE` storage type is rejected by Polaris 1.6 even with `ALLOW_INSECURE_STORAGE_TYPES=true`. Paid unlock: LocalStack Pro or MiniStack Pro implement AssumeRole with the credential shape Polaris needs.

## 2. Why the holes exist — the two-sentence version

1. **Protocol.** Nessie and Polaris are **Iceberg-REST-family** catalogs; Delta and Hudi are **Hive-metastore-family** (or, in Hudi's case, `_hoodie`-timeline-on-storage). No shared commit protocol → no cross-format sharing.
2. **Ownership.** Only one catalog can be `spark_catalog`. Delta's `DeltaCatalog` claims it in this stack, so Hudi (whose `HoodieCatalog` is a `DelegatingCatalogExtension` that also needs to *be* `spark_catalog`) can't have its own registered catalog and rides through `spark_catalog + USING hudi + LOCATION`.

Everything else in the grid follows from those two rules.

## 3. Explorer coverage

Same information as the "Explorer(s)" column above, sliced the other way — pick a UI, see which cells it covers:

| Explorer | What it browses | Cells |
|---|---|---|
| **Nimtable** (Iceberg REST catalog browser) | Iceberg tables via REST — Nessie's `/iceberg/`, Polaris's `/api/catalog`. Schemas, snapshots, manifests. | `nessie_catalog`+Iceberg, `polaris_catalog`+Iceberg |
| **Superset** (opt-in; over Spark Thrift on `:10000`, WS9) | Every catalog + every format — Spark speaks all of them; Superset just SQL-queries what Spark sees. | Every ✅ cell |
| **Spark SQL** (`SHOW`/`DESCRIBE`/`SELECT` from a notebook) | Every catalog + every format — the always-works floor. | Every ✅ cell |
| **StackPort** (AWS resource browser at `:8082`) | Raw S3 — buckets, prefixes, parquet/log/metadata files under `s3://warehouse/…`. Glue DB/table view too. | The physical files behind every ✅ cell |

**Deliberate design:** no single UI hides all three formats behind one abstraction. Nimtable is a *depth* tool (Iceberg internals — snapshot lineage, manifest tree). Superset is a *breadth* tool (one SQL surface over everything). StackPort is the *ground-truth* tool (what actually landed on S3). Students learn to reach for the one that answers their question — the same shape as production observability stacks.

## 4. What the user decides

The stack **exposes all catalogs + all formats**. Invalid combos aren't hidden — they fail with an understandable, documented message so students hit the boundary knowingly:

- `CREATE TABLE nessie_catalog.marts.t (…) USING delta` → Iceberg REST catalog rejects the DDL (protocol mismatch [A]) — that's the *lesson*, not the *bug*.
- `CREATE TABLE hudi_catalog.…` → `hudi_catalog` isn't in `spark-defaults.conf` (see [C]). The Spark error names the missing catalog directly; the fix is the `spark_catalog + USING hudi + LOCATION` pattern (cell [3]).
- `INSERT INTO polaris_catalog.marts.t …` → 502 from Polaris's storage-credential path ([F]) — the CAT-5 governed-marts destination is `glue_catalog` for exactly this reason.

Notebook markdown pre-empts each of these with a "if you try X, you'll get Y, because Z" note where the lesson would otherwise trip a student.

## 5. Cross-links

- **Lessons that live in these cells:**
  - LAK-1..10 — `iceberg_catalog` + Iceberg (cell [1]).
  - LAK-11 / LAK-12 — `spark_catalog` + Hudi (cell [3]).
  - CAT-1 — `nessie_catalog` + Iceberg (cell [4]); three-way agreement gate.
  - CAT-2 — `polaris_catalog` + Iceberg **read/RBAC** (cell [5]); "control-plane RBAC playground."
  - CAT-3 — `nessie_catalog` branches (cell [4]) via Nessie SQL extension — SQL-first per PLAN_V2 §WS8.
  - CAT-5 — cross-catalog federation: Nessie staging → **`glue_catalog`** governed marts (cells [4] → [6]), replacing the older Nessie → `iceberg_catalog` anti-pattern-marts.
  - DBT-1 / `dbt/models/marts/fct_orders_hudi.sql` — `spark_catalog` + Hudi with `location_root='s3a://warehouse/hudi/marts'` (cell [3]).
- **Design docs & plans:**
  - [`PLAN_V2.md`](./PLAN_V2.md) — the plan-of-record; §WS5 (this doc) and §WS9 (explorer research → Superset). Also carries the "Known limitations" (Polaris STS block [F]) that the older catalogs/Hudi/S3 planning docs used to hold.
  - [`CURRICULUM_PLAN.md`](./CURRICULUM_PLAN.md) — Phase 2.5 / 2.6 module IDs referenced above.
- **API playground for the control-plane surface** (branch/merge admin, OAuth token fetch, RBAC grants, curl-level catalog exploration): `iceberg/catalog_api_playground.ipynb` (per PLAN_V2 §WS3).
- **Configuration:** `conf/spark-defaults.conf` — catalog registrations for every row of the matrix, with inline commentary that mirrors this doc.
