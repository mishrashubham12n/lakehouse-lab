# =============================================================================
# make/explorer.mk — opt-in exploration UIs
#   - StackPort  : AWS resource browser (S3/Glue/IAM against MiniStack)
#   - Superset   : universal SQL explorer over Spark Thrift (all catalogs)
# Both live behind the `explorer` compose profile.
# =============================================================================

.PHONY: stackport-up stackport-down superset-up superset-down

stackport-up: ## Start StackPort (AWS resource browser at :8082) — opt-in
	docker compose --profile explorer up -d stackport
	@echo ""
	@echo "  StackPort : http://localhost:$${STACKPORT_PORT:-8082}  (browse MiniStack S3, Glue, IAM)"

stackport-down: ## Stop StackPort
	docker compose stop stackport
	docker compose rm -f stackport

superset-up: ## Start Superset (universal explorer at :8088, admin/admin) — opt-in
	docker compose --profile explorer up -d superset-postgres superset
	@echo ""
	@echo "  Superset  : http://localhost:$${SUPERSET_PORT:-8088}  (admin/admin)"
	@echo "  Add DB    : SQLAlchemy URI -> hive://spark-connect:10000/default"
	@echo "  First boot takes ~90-120s (installs pyhive on top of the base image)."

superset-down: ## Stop Superset
	docker compose stop superset superset-postgres
	docker compose rm -f superset superset-postgres
