# =============================================================================
# make/catalogs.mk — Nessie + Polaris + Nimtable (Phase 2.5, opt-in)
# =============================================================================

.PHONY: catalogs-up catalogs-down catalogs-clean nessie-reset

catalogs-up: ## Start Nessie + Polaris + Nimtable (Iceberg REST catalogs + UI) — Phase 2.5
	@mkdir -p .tmp/nessie .tmp/polaris
	docker compose --env-file .env --env-file conf/profiles/tuned.env --profile catalogs up -d
	@echo ""
	@bash services/catalogs/scripts/bootstrap-polaris.sh
	@echo ""
	@echo "  Nessie   : http://localhost:$${NESSIE_PORT:-19120}  (Iceberg REST + branching)"
	@echo "  Polaris  : http://localhost:$${POLARIS_PORT:-8181}  (Iceberg REST + RBAC — API-only, NO browser UI)"
	@echo "             health :  http://localhost:$${POLARIS_MGMT_PORT:-8182}/q/health"
	@echo "             to browse Polaris tables in a UI, open Nimtable below and select the 'polaris' catalog."
	@echo "  Nimtable : http://localhost:$${NIMTABLE_PORT:-8090}  (Iceberg catalog browser UI — admin/admin)"
	@echo "             browses Nessie AND Polaris; login = admin/admin (local lab default)."

catalogs-down: ## Stop ONLY the catalog services (leaves base stack running)
	docker compose stop nessie polaris polaris-postgres nimtable nimtable-web
	docker compose rm -f nessie polaris polaris-postgres polaris-bootstrap nimtable nimtable-web

catalogs-clean: catalogs-down ## Stop + wipe catalog state (fresh boot next `catalogs-up`)
	rm -rf .tmp/nessie .tmp/polaris
	@echo "Wiped Nessie RocksDB + Polaris Postgres data. Next 'make catalogs-up' reinitializes."

nessie-reset: ## Drop ALL Nessie table pointers on main (use after `make clean` wipes S3 out from under Nessie)
	@# Nessie is a commit graph pointing at Iceberg metadata.json files on S3.
	@# When students `make clean` (wipe MiniStack) the S3 pointers dangle:
	@# subsequent `DROP TABLE IF EXISTS` hits a 404 on metadata.json before it
	@# can drop the Nessie ref. This target does a REST-level delete of every
	@# table key on `main`, restoring a clean slate WITHOUT nuking RocksDB
	@# (branches / commit history survive; only tables are cleared).
	@uv run python -c "$$NESSIE_RESET_PY"

# Shared body — kept out of the recipe so make doesn't try to expand $$vars.
define NESSIE_RESET_PY
import urllib.request, urllib.parse, json, sys
BASE = 'http://localhost:19120/api/v2'

def api(method, path, body=None):
    req = urllib.request.Request(f'{BASE}{path}', method=method,
        data=json.dumps(body).encode() if body else None,
        headers={'Content-Type': 'application/json'} if body else {})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read()) if r.status != 204 else {}

main_ref = api('GET', '/trees/main')['reference']
head = main_ref['hash']
ref_path = urllib.parse.quote('main@' + head)
entries = api('GET', '/trees/' + ref_path + '/entries')['entries']
tables = [e for e in entries if e.get('type') == 'ICEBERG_TABLE']
if not tables:
    print('  nessie-reset : no tables on main to clear'); sys.exit(0)

ops = [{'type': 'DELETE', 'key': e['name']} for e in tables]
api('POST', '/trees/main@' + head + '/history/commit', {
    'commitMeta': {'message': 'nessie-reset: drop dangling table pointers'},
    'operations': ops,
})
print('  nessie-reset : cleared ' + str(len(tables)) + ' table pointer(s) on main')
endef
export NESSIE_RESET_PY
