# =============================================================================
# make/dbt.mk — dbt convenience wrappers
# =============================================================================
# Or: cd dbt && source ../.env && dbt <cmd>
# =============================================================================

.PHONY: dbt-build dbt-debug dbt-validate

dbt-build: ## Full dbt pipeline: seed + run + test
	@set -a && [ -f .env ] && . ./.env && set +a && \
	cd dbt && uv run dbt build --profiles-dir .

dbt-debug: ## Verify dbt connection to Spark Thrift Server
	@set -a && [ -f .env ] && . ./.env && set +a && \
	cd dbt && uv run dbt debug --profiles-dir .

dbt-validate: ## Validate every (transpiled) model on Spark with zero data (dbt build --empty)
	@set -a && [ -f dbt/.env ] && . ./dbt/.env && set +a && \
	cd dbt && uv run dbt build --empty
