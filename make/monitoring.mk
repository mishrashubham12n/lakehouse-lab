# =============================================================================
# make/monitoring.mk — Observability stack (CAP-3, opt-in)
# =============================================================================

.PHONY: monitoring-up monitoring-down monitoring-logs

monitoring-up: ## Start observability (Prometheus + Grafana + exporters) — CAP-3
	docker compose --env-file .env --env-file conf/profiles/tuned.env --profile monitoring up -d
	@echo ""
	@echo "  Prometheus : http://localhost:$${PROMETHEUS_PORT:-9090}  (Status → Targets)"
	@echo "  Grafana    : http://localhost:$${GRAFANA_PORT:-3000}  (admin/admin; Prometheus datasource pre-provisioned)"
	@echo "  Exporters  : kafka :9308 · postgres :9187 (postgres-exporter needs 'make cdc-up')"
	@echo ""
	@echo "  Import Grafana dashboards by ID: Kafka 7589 · Postgres 9628 · Spark (search 'spark')."

monitoring-down: ## Stop ONLY the observability services
	docker compose stop prometheus grafana kafka-exporter postgres-exporter
	docker compose rm -f prometheus grafana kafka-exporter postgres-exporter

monitoring-logs: ## Tail Prometheus + Grafana logs
	docker compose logs -f prometheus grafana
