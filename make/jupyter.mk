# =============================================================================
# make/jupyter.mk — Local JupyterLab (Spark Connect client)
# =============================================================================

.PHONY: jupyter jupyter-stop

jupyter: jupyter-stop ## Start JupyterLab locally (kills existing session first)
	@set -a && [ -f .env ] && . ./.env && set +a && \
	PYTHONPATH="$(PWD)" \
	uv run jupyter lab \
		--ip=127.0.0.1 \
		--port=$${JUPYTER_PORT:-8888} \
		--no-browser \
		--ServerApp.token="$${JUPYTER_TOKEN:-}" \
		--ServerApp.password=""

jupyter-stop: ## Stop any running JupyterLab session
	@-pkill -f "jupyter-lab" 2>/dev/null && echo "Stopped existing JupyterLab." || true
