# =============================================================================
# make/airflow.mk — Local Airflow standalone (Phase 6)
# =============================================================================

.PHONY: airflow-up airflow-down airflow-logs airflow-clean

AIRFLOW_HOME := $(PWD)/airflow/.airflow_home
AIRFLOW_LOG  := $(AIRFLOW_HOME)/logs/standalone.log

airflow-up: airflow-down ## Start Airflow locally (standalone, UI at :5000)
	@mkdir -p $(AIRFLOW_HOME)/logs
	@echo ""
	@echo "Airflow starting in background..."
	@echo "  Web UI : http://localhost:$${AIRFLOW_PORT:-5000}"
	@echo "  Login  : airflow / airflow"
	@echo "  DAGs   : ./airflow/dags/"
	@echo "  Logs   : make airflow-logs"
	@echo ""
	@AIRFLOW_HOME=$(AIRFLOW_HOME) \
	AIRFLOW__CORE__DAGS_FOLDER=$(PWD)/airflow/dags \
	AIRFLOW__CORE__LOAD_EXAMPLES=false \
	AIRFLOW__WEBSERVER__WEB_SERVER_PORT=$${AIRFLOW_PORT:-5000} \
	AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_USERS=airflow:admin \
	AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_PASSWORDS_FILE=$(PWD)/airflow/passwords.json \
	bash -c 'cd $(PWD)/airflow && nohup uv run airflow standalone >> $(AIRFLOW_LOG) 2>&1 &'

airflow-logs: ## Tail Airflow standalone logs
	@tail -f $(AIRFLOW_LOG)

airflow-down: ## Stop Airflow (kills all Airflow processes)
	@-pkill -f "$(PWD)/airflow/.venv/bin/airflow" 2>/dev/null && echo "Stopped Airflow." || echo "Airflow is not running."

airflow-clean: airflow-down ## Remove Airflow runtime state (DB, logs)
	rm -rf $(AIRFLOW_HOME)
	@echo "Cleaned Airflow state. Next 'make airflow-up' will reinitialize."
