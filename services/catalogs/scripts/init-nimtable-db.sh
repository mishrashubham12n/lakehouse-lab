#!/bin/bash
# =============================================================================
# Runs at Postgres startup — creates the `nimtable` database in polaris-postgres
# so Nimtable can share the same Postgres server as Polaris (one container,
# two logical DBs).
# =============================================================================
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE ${NIMTABLE_DB:-nimtable};
    GRANT ALL PRIVILEGES ON DATABASE ${NIMTABLE_DB:-nimtable} TO $POSTGRES_USER;
EOSQL
