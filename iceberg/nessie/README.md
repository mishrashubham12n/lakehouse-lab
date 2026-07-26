# Nessie — Git-for-data catalog lessons

Two interactive lessons in this folder, both `.ipynb`. The narrative is folded into the notebook markdown; this README is the run/prereqs/teardown pointer.

| Lesson | File | What it teaches |
|---|---|---|
| **CAT-1** | [`cat1_nessie_intro.ipynb`](./cat1_nessie_intro.ipynb) | Same Iceberg table on two catalogs (Hadoop `version-hint.text` vs Nessie REST) — where the current-snapshot pointer lives. |
| **CAT-3** | [`cat3_branching.ipynb`](./cat3_branching.ipynb) | Git-like branching in Spark SQL — `CREATE BRANCH … FROM main`, `USE REFERENCE`, `MERGE BRANCH`. Uses the Nessie Spark SQL extension. |

## Prereqs

```bash
make up            # Spark Connect + MiniStack
make catalogs-up   # + Nessie, Polaris, Nimtable
```

Then open either notebook. The kernel connects via Spark Connect (`sc://localhost:15002`); the notebook's CWD must be the notebook's own directory (standard Jupyter behaviour).

## Teardown

Each notebook drops the tables it creates (and CAT-3 drops its `cat3_dev` branch). `make clean` wipes MiniStack + Nessie's RocksDB for a fully fresh warehouse.

## Known limits

- CAT-3's SQL surface requires the Nessie Spark extension (`nessie-spark-extensions-4.0_2.13:0.108.0`), baked into the image. `spark-defaults.conf` already wires it into `spark.sql.extensions` alongside Iceberg/Hudi/Delta.
- Cross-catalog **admin** operations (raw REST — list refs, create branch via curl, OAuth token flow) live in [`../catalog_api_playground.ipynb`](../catalog_api_playground.ipynb) — the *lessons* stay SQL.
