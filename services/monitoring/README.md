# Monitoring — Prometheus + Grafana + exporters

**What it is:** Prometheus scrapes Kafka, Postgres, and Spark. Grafana visualizes. Used by CAP-3 (observability capstone).

**Managed by:** `make monitoring-up` / `make monitoring-down` (profile: `monitoring`, opt-in).

## Ports

| Port | What                              |
|------|-----------------------------------|
| 9090 | Prometheus web UI                 |
| 3000 | Grafana (admin/admin)             |
| 9308 | Kafka exporter (Prometheus target)|
| 9187 | Postgres exporter (Prometheus target) |

## Grafana dashboards (import by ID)

| Dashboard | ID   | What it shows                        |
|-----------|------|--------------------------------------|
| Kafka     | 7589 | Broker throughput, consumer lag      |
| Postgres  | 9628 | Connection pool, replication lag     |
| Spark     | search "spark" | JVM, executor, task metrics |

## How to interact

```bash
# Prometheus targets
open http://localhost:9090/targets

# Grafana (anonymous read enabled — no login needed for browsing)
open http://localhost:3000

# Tail logs
make monitoring-logs
```

## Dependencies

- **postgres-exporter needs `make cdc-up`** — without it there's no database to read (target will show `down` until you start CDC).
- **Spark metrics need `spark.ui.prometheus.enabled=true`** in `spark-defaults.conf` (already set) — restart `spark-connect` after enabling if it wasn't already.

## Gotchas

- Grafana data persists to a named volume (`lakehouse-lab-grafana-data`). `make clean-all` removes it.
- Prometheus retention is default (15d). For long teaching runs this is fine.
