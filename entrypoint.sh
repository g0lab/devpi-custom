#!/bin/bash

set -e

DEVPI_DATA_DIR="${DEVPI_DATA_DIR:-/data/devpi}"
DEVPI_PORT="${DEVPI_PORT:-3141}"
DEVPI_HOST="${DEVPI_HOST:-0.0.0.0}"
DEVPI_USER="${DEVPI_USER:-pypi}"
DEVPI_INDEX="${DEVPI_INDEX:-constrained}"
ALLOWED_FILE="${ALLOWED_FILE:-/etc/devpi/allowed.txt}"

# Initialise the server data directory on first run
if [ ! -f "${DEVPI_DATA_DIR}/.nodeinfo" ]; then
    echo "Initialising devpi server data directory..."
    devpi-init --serverdir "${DEVPI_DATA_DIR}"
fi

# Start server in the background for initial configuration
devpi-server --serverdir "${DEVPI_DATA_DIR}" --host 127.0.0.1 --port "${DEVPI_PORT}" &
SERVER_PID=$!

# Wait until the server is ready
echo "Waiting for devpi server to become ready..."
until curl -sf "http://127.0.0.1:${DEVPI_PORT}/+api" > /dev/null 2>&1; do
    sleep 1
done
echo "Server ready."

devpi use "http://127.0.0.1:${DEVPI_PORT}"
devpi login root --password ""

# Create the index user if it doesn't exist yet
devpi user -c "${DEVPI_USER}" email="${DEVPI_USER}@localhost" password="" 2>/dev/null \
    || echo "User '${DEVPI_USER}' already exists."

devpi login "${DEVPI_USER}" --password ""

# Create the constrained index if it doesn't exist yet
devpi index -c "${DEVPI_INDEX}" type=constrained bases=root/pypi 2>/dev/null \
    || echo "Index '${DEVPI_USER}/${DEVPI_INDEX}' already exists."

devpi use "${DEVPI_USER}/${DEVPI_INDEX}"

# Apply constraints from allowed.txt
if [ -f "${ALLOWED_FILE}" ]; then
    # Strip comments and blank lines; devpi-constrained expects newline-separated entries
    CONSTRAINTS=$(grep -v '^[[:space:]]*#' "${ALLOWED_FILE}" | grep -v '^[[:space:]]*$')
    if [ -n "${CONSTRAINTS}" ]; then
        # Append the wildcard blocker so everything not listed is rejected
        devpi index "constraints=$(printf '%s\n*' "${CONSTRAINTS}")"
        echo "Constraints applied from ${ALLOWED_FILE} (+ wildcard block)"
    else
        devpi index "constraints=*"
        echo "Warning: ${ALLOWED_FILE} is empty — all packages blocked."
    fi
else
    echo "Warning: ${ALLOWED_FILE} not found — no constraints applied."
fi

# Stop the background server cleanly
kill "${SERVER_PID}"
wait "${SERVER_PID}" 2>/dev/null || true

echo "Starting devpi server..."
exec devpi-server \
    --serverdir "${DEVPI_DATA_DIR}" \
    --host "${DEVPI_HOST}" \
    --port "${DEVPI_PORT}"
