# =============================================================================
# lakehouse-lab — thin orchestrator that includes make/*.mk
# =============================================================================
# Each subsystem owns its own targets in make/<name>.mk. Adding a subsystem
# is one make/<name>.mk + one include line below. No cross-file surgery.
# =============================================================================

.DEFAULT_GOAL := help

include make/base.mk
include make/cdc.mk
include make/monitoring.mk
include make/catalogs.mk
include make/explorer.mk
include make/jupyter.mk
include make/dbt.mk
include make/airflow.mk

.PHONY: help

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / \
		{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) \
		| sort -u
