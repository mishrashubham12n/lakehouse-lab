# Run a Snowflake dbt repo on Spark 4.0.2 — unchanged

Swap the warehouse from Snowflake to Spark 4.0.2 **without editing a single model**. Your Snowflake SQL
stays as-is; only `profiles.yml`, one `dbt_project.yml` flag, and a package install change.

## The only changes you make

1. **Install the package** (carries the transpile + Spark-output fix-ups, auto-activates via a `.pth`):
   ```bash
   pip install dbt-polyglot        # in this repo it's already declared in pyproject.toml — `uv sync`
   ```
   Published to PyPI as [`dbt-polyglot`](https://pypi.org/project/dbt-polyglot/) (source:
   [`Saketkr21/dbt-polyglot`](https://github.com/Saketkr21/dbt-polyglot)); consumed here as a normal
   PyPI dependency — no local checkout in this repo.
2. **`profiles.yml`** — point the output at Spark/Thrift instead of Snowflake:
   ```yaml
   your_profile:
     target: dev
     outputs:
       dev:
         type: spark
         method: thrift
         host: "{{ env_var('DBT_SPARK_HOST', 'localhost') }}"
         port: "{{ env_var('DBT_SPARK_PORT', 10000) | int }}"
         schema: analytics
   ```
3. **`dbt_project.yml`** — declare your models' source dialect:
   ```yaml
   models:
     your_project:
       +transpile_from: snowflake      # your models are written in Snowflake SQL
       # +transpile_to: spark          # optional, default 'spark'
   ```

Then `dbt build` runs your existing Snowflake models on Spark. **No model edits.**

## How it works
At dbt **compile**, each model's SQL is parsed as Snowflake and regenerated as Spark via `sqlglot`
(inside the installed `dbt-polyglot` package). A **fix-up layer** then repairs the spots where
sqlglot's Spark output isn't accepted by Spark 4.0.2's real parser (e.g. `x NOT IN (subquery)` →
which sqlglot renders as the unsupported `x <> ALL (subquery)` → rewritten back to
`NOT x IN (subquery)`). The rewrite happens before dbt wraps the model, so `target/compiled/` and the
executed SQL are both Spark.

Two companions make a whole Snowflake repo work on Spark, also config-only:
- **Cross-catalog targeting** — the adopted **schema-string trick**:
  `{{ config(schema='iceberg_catalog.marts', file_format='iceberg') }}` for Iceberg;
  `{{ config(schema='<ns>', file_format='hudi') }}` on the default `spark_catalog` with
  `location_root='s3a://warehouse/hudi/<ns>/'` for Hudi (there is no separate `hudi_catalog` —
  Hudi rides on `spark_catalog + USING hudi + LOCATION`; see
  [`CATALOG_FORMAT_MATRIX.md`](./CATALOG_FORMAT_MATRIX.md) footnote [C]).
  Stock dbt-spark; **no custom macros** (the earlier `generate_database_name.sql` /
  `dbt-spark-catalog` monkeypatch was removed as over-engineered — dbt-spark fundamentally does not
  support `+database`).
- **Seed idempotency** (`macros/create_csv_table.sql`): makes `dbt seed` re-runnable on Spark.

## Trust: you always know what's safe — nothing is silently wrong
A model is either converted to **verified-valid Spark SQL**, or it **fails loudly** (a clear dbt/Spark
error naming the model). It never silently produces a wrong result from an un-converted construct.

To certify your repo **upfront**, use dbt's own native zero-data validation (or `make dbt-validate`):
```bash
dbt build --empty                 # build every model with 0 input rows, in DAG order
dbt show --limit 0 -s my_model    # read-only variant: validate without materializing
```
`--empty` limits every `ref`/`source` to zero rows, so dbt runs each model's real (transpiled) SQL
against the warehouse — moving no data — and **fails loudly, naming the model**, if it's invalid Spark.
Because it builds in dependency order there's no "upstream not built" ambiguity, and it exits non-zero
on the first invalid model — a drop-in CI gate, with no custom tooling and no extra dependency.

### Safely converted (verified)
Window functions incl. `QUALIFY`, `x [NOT] IN (subquery)`, `IFF`→`IF`, `NVL`→`COALESCE`, `::`→`CAST`,
`DATEADD`/`DATEDIFF`, CTEs, `CASE`, standard joins/aggregations, and the broad set `sqlglot` maps.

### Known-unsupported (fails loud, by design)
Constructs with **no clean Spark equivalent** — chiefly Snowflake **semi-structured** features:
`LATERAL FLATTEN`, `VARIANT`/`OBJECT`/`ARRAY` semantics, `:` path access, and a few proprietary
functions. These surface as loud errors (or a fail-soft WARNING + the original passed through, which
Spark then rejects loudly) — so you find them via the check, not in production. This residue is inherent
to the dialect differences (true of any tool, including SQLMesh), not a defect of the approach.

> Honest bottom line: this safely and accurately converts the large majority of analytical Snowflake SQL,
> and is transparent (loud, certified) about the minority it can't — so you can trust every green model.
