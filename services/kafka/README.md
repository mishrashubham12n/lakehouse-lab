# Kafka + Kafka UI

**What it is:** Single-broker Kafka in KRaft mode (no ZooKeeper) plus the Provectus Kafka UI. Used by Phase 3 (streaming) and Phase 4 (CDC).

**Managed by:** `make up` / `make down` (always-on, no profile).

## Ports

| Port  | What                             |
|-------|----------------------------------|
| 29092 | Kafka broker (external, host-side) |
| 9092  | Kafka broker (internal, container network) |
| 9093  | KRaft controller (internal)     |
| 8080  | Kafka UI (web)                  |

## Bootstrap servers

- From host (Jupyter, Python scripts): `localhost:29092`
- From inside Docker network (Spark, Connect): `kafka:9092`

## Single-broker gotcha (KAF-5)

RF=1 pinned on `KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR` and `KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR`. Default is 3 — a lone broker cannot satisfy it, so any idempotent/transactional producer hangs on `initProducerId`.

## How to interact

```bash
# Web UI
open http://localhost:8080

# List topics from host
docker compose exec kafka \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

# From Python
from kafka import KafkaProducer
p = KafkaProducer(bootstrap_servers="localhost:29092")
```

## Gotchas

- The `EXTERNAL` listener advertises `localhost:29092` — that only works from the host. From another container use `kafka:9092`.
- No named volume — messages are ephemeral. `docker compose down && docker compose up` = clean slate.
