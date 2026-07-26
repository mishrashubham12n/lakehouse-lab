# =============================================================================
# make/cdc.mk — Debezium CDC track (Phase 4, opt-in)
# =============================================================================

.PHONY: cdc-up cdc-down cdc-logs

cdc-up: ## Start the CDC services (Postgres + Kafka Connect/Debezium) — Phase 4
	docker compose --env-file .env --env-file conf/profiles/tuned.env --profile cdc up -d
	@echo ""
	@echo "  Postgres      : localhost:$${POSTGRES_PORT:-5432}  (user/pass cdc/cdc, db inventory)"
	@echo "  Kafka Connect : http://localhost:$${CONNECT_PORT:-8083}  (Debezium REST API)"
	@echo ""
	@echo "  CDC adds ~1.3 GB. On an 8 GB laptop, stop optional services first:"
	@echo "    docker compose stop spark-history kafka-ui"

cdc-down: ## Stop ONLY the CDC services (leaves base stack running)
	docker compose stop postgres kafka-connect
	docker compose rm -f postgres kafka-connect

cdc-logs: ## Tail Kafka Connect logs
	docker compose logs -f kafka-connect
