#!/bin/bash
set -euo pipefail

export DB_HOST="${DB_HOST:-db}"
export DB_PORT="${DB_PORT:-5432}"
export DB_USER="${DB_USER:-postgres}"
export DB_PASSWORD="${DB_PASSWORD:-postgres}"
export TACTIC_HOSTNAME="${TACTIC_HOSTNAME:-localhost}"
export TACTIC_PROTOCOL="${TACTIC_PROTOCOL:-http}"
export VFX_PROJECT_CODE="${VFX_PROJECT_CODE:-vfx}"
export VFX_PROJECT_TITLE="${VFX_PROJECT_TITLE:-VFX}"

CONF_DIR="${TACTIC_DATA_DIR}/config"
CONF="${CONF_DIR}/tactic-conf.xml"

# Seed the data dir (config, start templates) on first run
mkdir -p "${CONF_DIR}" "${TACTIC_DATA_DIR}/assets" "${TACTIC_DATA_DIR}/dist" "${TACTIC_TMP_DIR}"
[ -d "${TACTIC_DATA_DIR}/templates" ] || cp -r "${TACTIC_INSTALL_DIR}/src/install/start/templates" "${TACTIC_DATA_DIR}/templates"
[ -f "${CONF_DIR}/tactic-license.xml" ] || cp "${TACTIC_INSTALL_DIR}/src/install/template/config/tactic-license.xml" "${CONF_DIR}/"

# Render the config from env on first run only, so manual edits in the volume persist
if [ ! -f "${CONF}" ]; then
    envsubst '${TACTIC_HOSTNAME} ${TACTIC_PROTOCOL} ${TACTIC_TMP_DIR} ${TACTIC_DATA_DIR} ${DB_HOST} ${DB_PORT} ${DB_USER} ${DB_PASSWORD}' \
        < /opt/tactic/tactic-conf.xml.template > "${CONF}"
fi

echo "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT} ..."
until PGPASSWORD="${DB_PASSWORD}" pg_isready -q -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}"; do
    sleep 1
done

python /opt/tactic/bootstrap_db.py

# Create the VFX production project from TACTIC's built-in VFX plugin (first start only)
if [ "${VFX_ENABLED:-true}" = "true" ]; then
    python /opt/tactic/bootstrap_vfx.py
fi

exec "$@"
