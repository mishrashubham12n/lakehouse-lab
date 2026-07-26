# =============================================================================
# services/explorer/superset/superset_config.py
# -----------------------------------------------------------------------------
# Mounted at /app/pythonpath/superset_config.py inside the Superset container.
# Superset picks it up via PYTHONPATH (set by the base image).
#
# THIS IS A LOCAL LAB CONFIG. `SUPERSET_SECRET_KEY` is a hard-coded fallback so
# the container boots for a workshop without env plumbing. Do NOT reuse this
# config anywhere close to production.
# =============================================================================

import os

# --- secrets --------------------------------------------------------------
# Overridden by the SUPERSET_SECRET_KEY env var; the fallback string is only
# ever hit if the compose file forgets to set it.
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "dev-only-not-secret")

# --- metadata db ----------------------------------------------------------
# Small Postgres instance in this compose file — see `superset-postgres`.
# NOT the polaris-postgres in services/catalogs (owned by that subsystem).
SQLALCHEMY_DATABASE_URI = (
    "postgresql+psycopg2://superset:superset@superset-postgres:5432/superset"
)

# --- ui / behavior --------------------------------------------------------
# Row limit for SQL Lab / explorer previews. Lab queries are small; keep tight.
ROW_LIMIT = 5000
SQLLAB_TIMEOUT = 300
SUPERSET_WEBSERVER_TIMEOUT = 300

# Turn on a couple of quality-of-life feature flags.
FEATURE_FLAGS = {
    "DASHBOARD_NATIVE_FILTERS": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "ENABLE_TEMPLATE_PROCESSING": True,
}

# --- misc -----------------------------------------------------------------
# We connect Superset -> Spark Thrift Server via `hive://` — a SQLAlchemy URL.
# Nothing extra to configure here; the pyhive driver is installed at container
# start (see the entrypoint in services/explorer/compose.yml).
