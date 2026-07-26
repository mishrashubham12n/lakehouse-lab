# Explorer — Superset over Spark Thrift Server

**What it is:** [Apache Superset](https://superset.apache.org) fronted onto the Spark Thrift Server that `spark-connect` already runs on port `10000`. Since the Spark JVM owns every registered catalog (`spark_catalog`/Delta, `iceberg_catalog`, `nessie_catalog`, `polaris_catalog`, `glue_catalog`), one Superset connection sees Iceberg, Delta and Hudi tables across all catalogs — the "universal" layer that Nimtable (Iceberg-REST only) cannot cover.

**Complements — does not replace — Nimtable.** Keep Nimtable for Iceberg snapshot / branch depth. Use Superset for cross-catalog browsing, cross-format SQL, and dashboards.

**Managed by:** `make superset-up` / `make superset-down` (profile: `explorer`, opt-in).

**Sibling on the same profile:** [`stackport`](../stackport/README.md) — the S3-native browser for what's actually on disk.

## Ports

| Port | What                 |
|------|----------------------|
| 8088 | Superset UI (host)   |

`superset-postgres` (Superset's metadata store) is internal-only — not published.

## Quick start

```bash
make up            # spark-connect (Thrift on :10000) + ministack + kafka
make superset-up   # brings up superset-postgres + superset (profile: explorer)
open http://localhost:8088
```

Login: **admin / admin** (local lab only — `SUPERSET_SECRET_KEY` is hard-coded as `dev-only-not-secret`; do **not** reuse this config outside the lab).

First boot takes ~1–2 minutes: the container `apt-get`s `libsasl2` and `pip install`s `pyhive[hive] + thrift + thrift_sasl` on top of `apache/superset:latest` so we don't own a Dockerfile just to add two libs. Restarts are fast — the container is the same one.

## Wire up the Thrift database

Superset UI → **Settings → Database Connections → + Database → Other**, then:

- **Display name:** `Spark Thrift (all catalogs)`
- **SQLAlchemy URI:** `hive://spark-connect:10000/default`
- **Test connection** → save.

`spark-connect` is the container name of the Spark unified server on the lab's default network, so Superset can reach it directly.

## Browse tables

**SQL Lab → SQL Lab → SQL Editor** — pick the Spark Thrift database, then:

```sql
-- 1. Warm the catalog registry (one-time per JDBC session — see the "gotcha"
--    below). Each `SHOW NAMESPACES` forces Spark to instantiate that catalog
--    plugin. Run these once and `SHOW CATALOGS` then lists all five.
SHOW NAMESPACES IN iceberg_catalog;
SHOW NAMESPACES IN nessie_catalog;
SHOW NAMESPACES IN glue_catalog;
SHOW NAMESPACES IN polaris_catalog;

-- 2. Now discovery works as expected
SHOW CATALOGS;                                -- all 5
SHOW DATABASES IN nessie_catalog;
SHOW TABLES IN nessie_catalog.default;

-- 3. Sample data — works on Iceberg, Delta, Hudi identically
SELECT * FROM spark_catalog.default.customers LIMIT 100;
SELECT * FROM nessie_catalog.default.orders     LIMIT 100;
```

**Datasets** — you can also register a table once (Datasets → + Dataset), then build charts and dashboards on top.

## Gotcha: `SHOW CATALOGS` and Spark's lazy catalog registry

Spark's `CatalogManager` is **per-session and lazy** — a fresh JDBC/Connect session sees only `spark_catalog` in `SHOW CATALOGS` until a catalog plugin is *touched* (any `SHOW NAMESPACES IN <cat>` / `USE <cat>` counts). This is a Spark behavior, not a Superset one.

- **In notebooks:** already fixed automatically — `common/spark_session.py` warms every configured catalog at session start, so `SHOW CATALOGS` lists all five immediately.
- **In Superset / any raw JDBC client:** run the four `SHOW NAMESPACES IN <cat>` warm-up queries above once at the start of a session. Superset lets you save that as a Query in SQL Lab and re-run it in one click. **Datasets are unaffected** — they reference tables by fully-qualified name (`glue_catalog.marts.orders_daily`), and Superset resolves those against Spark whether the catalog has been "shown" or not.

## Known limits (be honest with students)

- **No true cross-catalog global search box.** You pick a catalog, then browse. This is a Superset/JDBC limit, not a Spark one — the WS5 explorer matrix flags this cell.
- **No Iceberg snapshot / branch UI.** That's what Nimtable is for — use both.
- **First launch is slow (~90–120 s)** because of the pip/apt install; the `healthcheck` hides this behind a 120 s `start_period`.

## Curriculum touchpoints

- **WS5 matrix** — fills the "explorer" column with Superset for every (catalog × format) cell Nimtable can't reach.
- **CAT-* modules** — students point Superset at each catalog they register and confirm the same table is visible via Spark, Nimtable (if Iceberg), and Superset.
- **Capstone dashboards** — optional: build a KPI dashboard on top of the marts produced in Phase 5 (dbt) / Phase 7 (capstone).
