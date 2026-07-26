# CDC — Postgres + Kafka Connect (Debezium)

**What it is:** Postgres 16 running in logical-replication mode + Kafka Connect with the Debezium Postgres connector. Used by Phase 4 (CDC-1..CDC-9).

**Managed by:** `make cdc-up` / `make cdc-down` (profile: `cdc`, opt-in).

## Ports

| Port | What                               |
|------|------------------------------------|
| 5432 | Postgres (superuser cdc/cdc, db `inventory`) |
| 8083 | Kafka Connect REST API             |

## State

Ephemeral. Recreating the container gives a clean source; notebooks seed their own data.

## How to interact

```bash
# Postgres shell
docker compose exec postgres psql -U cdc -d inventory

# Register a Debezium source connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @debezium/config/pg-source.json

# List connectors
curl -sf http://localhost:8083/connectors | jq

# Tail Connect logs
make cdc-logs
```

## Gotchas

- `wal_level=logical` is set at postgres startup — required for Debezium's pgoutput plugin.
- `max_replication_slots=4` bounds concurrent Debezium instances. If a connector is not cleaned up (see CDC-5), the slot retains WAL and disk fills.
- Connect internal topics use `RF=1` to match the single-broker Kafka.
