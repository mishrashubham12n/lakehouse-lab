# =============================================================================
# make/base.mk — build/up/down for the always-on Docker stack
# =============================================================================
# Owns: build, up, up-constrained, _ports, down, restart, restart-constrained,
#       logs, status, clean, clean-all
# =============================================================================

.PHONY: build up up-constrained _ports down restart restart-constrained \
        logs status clean clean-all

build: ## Build Docker images
	docker compose build

up: ## Start the always-on stack — TUNED profile (~3 GB Spark; the default)
	@mkdir -p .tmp/spark-events .tmp/ministack logs
	cp -n .env.example .env
	docker compose --env-file .env --env-file conf/profiles/tuned.env up -d
	@$(MAKE) --no-print-directory _seed_warehouse_bucket
	@echo ""
	@echo "  Spark profile : TUNED       (conf/profiles/tuned.env)"
	@$(MAKE) --no-print-directory _ports

up-constrained: ## Start the always-on stack — CONSTRAINED (~2 GB Spark, 2 cores; OOM/spill modules)
	@mkdir -p .tmp/spark-events .tmp/ministack logs
	docker compose --env-file .env --env-file conf/profiles/constrained.env up -d
	@$(MAKE) --no-print-directory _seed_warehouse_bucket
	@echo ""
	@echo "  Spark profile : CONSTRAINED (conf/profiles/constrained.env)"
	@echo "  Use this profile for the OOM / spill modules so failure is real but the host stays usable."
	@$(MAKE) --no-print-directory _ports

_seed_warehouse_bucket: ## (internal) create the `warehouse` S3 bucket in MiniStack — idempotent
	@bash services/ministack/scripts/seed-warehouse.sh

_ports: ## (internal) print service URLs
	@echo "  Spark Connect : sc://localhost:$${SPARK_CONNECT_PORT:-15002}"
	@echo "  Spark UI      : http://localhost:$${SPARK_UI_PORT:-4040}"
	@echo "  History Server: http://localhost:$${SPARK_HISTORY_PORT:-18080}"
	@echo "  Kafka UI      : http://localhost:$${KAFKA_UI_PORT:-8080}"
	@echo "  MiniStack     : http://localhost:$${MINISTACK_PORT:-4566}  (S3 + Glue + IAM)"
	@echo ""
	@echo "  Opt-in add-ons: make catalogs-up | cdc-up | monitoring-up | stackport-up"
	@echo "  Local Jupyter : make jupyter"

down: ## Stop all Docker services
	docker compose down

restart: down up ## Restart all services (tuned profile)

restart-constrained: down up-constrained ## Restart all services (constrained profile)

logs: ## Tail Docker service logs
	docker compose logs -f

status: ## Show status of all services
	docker compose ps

clean: ## Remove generated data (all .tmp/ state — warehouses, catalogs, event logs)
	rm -rf .tmp app/data/streaming_input/*.json
	@echo "Cleaned .tmp/ — MiniStack buckets, Nessie RocksDB, Polaris H2, Spark events all wiped."

clean-all: clean ## Remove generated data + Docker named volumes
	docker compose down -v
	@echo "Cleaned Docker volumes too (ivy-cache, grafana-data)."
