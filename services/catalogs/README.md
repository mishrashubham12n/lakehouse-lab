# Catalogs — Nessie + Polaris + Nimtable

**What it is:** two Iceberg catalogs (each teaching a different production shape) plus a browser UI.

- **Nessie** — Git-like branching + merging for Iceberg tables. `CREATE BRANCH`, `USE REFERENCE`, `MERGE BRANCH` on entire datasets. Unique concept — no other catalog offers it.
- **Polaris** — Enterprise-shaped Iceberg REST catalog with RBAC (principals, roles, grants). Snowflake-donated, Apache TLP. RBAC + read work on this stack; **write is STS-blocked on MiniStack Community** — documented in `docs/PLAN_V2.md`.
- **Nimtable** — Iceberg-native browser UI (Next.js frontend + Java backend, two containers). Browses both catalogs, shows schemas, snapshots, partitions.

**Managed by:** `make catalogs-up` / `make catalogs-down` (profile: `catalogs`, opt-in).

## Ports

| Port  | What                                                       |
|-------|-------------------------------------------------------------|
| 19120 | Nessie REST (native `/api/v2` + Iceberg-REST `/iceberg/`) |
| 8181  | Polaris REST (`/api/catalog` + `/api/management/v1`)      |
| 8182  | Polaris management/health (`/q/health`)                    |
| 8090  | Nimtable web UI (admin/admin)                              |

Backends (internal only, not published):
- `nimtable:8182` — Nimtable Java backend REST API (consumed by nimtable-web)
- `polaris-postgres:5432` — Polaris + Nimtable metadata store

## State

All persistent state under `./.tmp/` — wiped by `make catalogs-clean`:

- `./.tmp/nessie/` — RocksDB (embedded)
- `./.tmp/polaris/` — Postgres data (`polaris-postgres` container)

## Spark catalog names

Configured in `conf/spark-defaults.conf`:

- **`nessie_catalog`** → `NessieCatalog` native at `http://nessie:19120/api/v2` (`client-api-version=2`, `ref=main`). Native protocol is needed so the Nessie Spark SQL extension (`CREATE BRANCH`, `USE REFERENCE`, `MERGE BRANCH`) resolves — the extension can't drive the Iceberg-REST adapter cleanly. Nimtable still browses Nessie via `/iceberg/` REST independently; both protocols read/write the same commit graph.
- **`polaris_catalog`** → Iceberg REST at `http://polaris:8181/api/catalog` with OAuth2 (`credential=root:secret`, `scope=PRINCIPAL_ROLE:ALL`).

## How to interact

```bash
# Nimtable browser UI (Iceberg-only browser — both catalogs)
open http://localhost:8090      # admin/admin

# Nessie config (native API)
curl -s http://localhost:19120/api/v2/config | jq

# Nessie branch operations via Spark SQL (CAT-3)
spark.sql("CREATE BRANCH dev IN nessie_catalog FROM main")
spark.sql("USE REFERENCE dev IN nessie_catalog")
spark.sql("MERGE BRANCH dev INTO main IN nessie_catalog")

# Polaris: OAuth2 token + list catalogs (CAT-2 style)
TOKEN=$(curl -s -X POST http://localhost:8181/api/catalog/v1/oauth/tokens \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Polaris-Realm: default" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=root" --data-urlencode "client_secret=secret" \
  --data-urlencode "scope=PRINCIPAL_ROLE:ALL" | jq -r .access_token)
curl -s -H "Authorization: Bearer $TOKEN" -H "Polaris-Realm: default" \
     http://localhost:8181/api/management/v1/catalogs | jq

# Polaris via Spark SQL (queries + RBAC-effect observation)
spark.sql("SHOW NAMESPACES IN polaris_catalog")
```

## Bootstrap

`make catalogs-up` triggers:
- `polaris-postgres` starts + becomes healthy (Postgres 16).
- `polaris-bootstrap` (`apache/polaris-admin-tool:1.6.0`) creates the schema + root principal (idempotent — exits 0 if already bootstrapped).
- `polaris` starts against the bootstrapped Postgres.
- `services/catalogs/scripts/bootstrap-polaris.sh` creates a MiniStack IAM `polaris-role` + the `lab` catalog with S3 storageConfig pointing at MiniStack (idempotent).
- `nimtable` (backend) + `nimtable-web` (Next.js UI) start.

## After `make clean`

`make clean` wipes S3 out from under Nessie — Nessie's RocksDB still remembers table pointers, but the underlying `metadata.json` files are gone → subsequent `DROP TABLE IF EXISTS` hits a 404. Run **`make nessie-reset`** to clear stale table pointers on `main` without nuking RocksDB (branches/commit history survive).

## Pedagogical progression (Phase 2.5)

| Module | Catalog(s) | What it teaches |
|--------|------------|-----------------|
| CAT-1  | Nessie             | Iceberg REST vs Hadoop catalog — a catalog owns the pointer |
| CAT-2  | Polaris            | RBAC — principals, roles, grants (control-plane playground) |
| CAT-3  | Nessie             | Git-like branching — SQL-first (`CREATE BRANCH / USE REFERENCE / MERGE BRANCH`) |
| CAT-5  | Nessie → Glue      | Cross-catalog federation — read from Nessie staging, write to Glue-catalog marts. Polaris was the original target but its write path is STS-blocked on MiniStack Community; `docs/PLAN_V2.md` §WS1 has the RCA. |
| `iceberg/catalog_api_playground.ipynb` | Both | Raw REST/OAuth plumbing sandbox — the plumbing the lessons deliberately hide. |

## Gotchas

- **Nessie SQL extension only works against `NessieCatalog` native**, not the Iceberg-REST adapter. Our config uses `.catalog-impl=org.apache.iceberg.nessie.NessieCatalog` + `client-api-version=2`. Nimtable's own client uses `/iceberg/` REST; the two protocols coexist against the same commit graph.
- **Polaris write is blocked in this OSS stack** — Polaris always calls STS AssumeRole, and MiniStack Community's STS emulator doesn't return credentials Polaris's SDK can complete an S3 request against. Polaris = RBAC/read-only here; the write demo lives on Glue. `LocalStack Pro` or `MiniStack Pro` would unblock it.
- **`Polaris-Realm: default` header** must accompany any management-API call.
- **Nimtable does not display Delta or Hudi tables** — they live in `spark_catalog`, which Nimtable can't browse. For those, use Superset (`make superset-up`), Spark SQL directly, or StackPort for the raw S3 files.
