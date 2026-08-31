#!/usr/bin/env bash
set -euo pipefail

DAEMON_HOME="${DAEMON_HOME:-/root/.gaia}"
CHAIN_ID="${CHAIN_ID:-cosmoshub-4}"
MONIKER="${MONIKER:-docker-gaia-node}"
GENESIS_URL="${GENESIS_URL:-}"
SEEDS="${SEEDS:-}"
PERSISTENT_PEERS="${PERSISTENT_PEERS:-}"

CONFIG_TOML="${DAEMON_HOME}/config/config.toml"
APP_TOML="${DAEMON_HOME}/config/app.toml"
GENESIS_JSON="${DAEMON_HOME}/config/genesis.json"

if [ ! -f "${GENESIS_JSON}" ]; then
  echo ">> no existing genesis found, running init"
  gaiad init "${MONIKER}" --chain-id "${CHAIN_ID}" --home "${DAEMON_HOME}"

  if [ -n "${GENESIS_URL}" ]; then
    curl -sSL "${GENESIS_URL}" -o "${GENESIS_JSON}"
  fi
  if [ -n "${SEEDS}" ]; then
    sed -i.bak -E "s|^seeds *=.*|seeds = \"${SEEDS}\"|" "${CONFIG_TOML}"
  fi
  if [ -n "${PERSISTENT_PEERS}" ]; then
    sed -i.bak -E "s|^persistent_peers *=.*|persistent_peers = \"${PERSISTENT_PEERS}\"|" "${CONFIG_TOML}"
  fi

  sed -i.bak -E 's|^laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' "${CONFIG_TOML}"
  sed -i.bak -E 's|^prometheus = false|prometheus = true|' "${CONFIG_TOML}"
  sed -i.bak -E 's|^prometheus_listen_addr = ".*"|prometheus_listen_addr = ":26660"|' "${CONFIG_TOML}"
  sed -i.bak -E 's|^address = "tcp://localhost:1317"|address = "tcp://0.0.0.0:1317"|' "${APP_TOML}"
  sed -i.bak -E 's|^enable = false|enable = true|' "${APP_TOML}"
  sed -i.bak -E 's|^address = "localhost:9090"|address = "0.0.0.0:9090"|' "${APP_TOML}"
  rm -f "${CONFIG_TOML}.bak" "${APP_TOML}.bak"
else
  echo ">> existing data directory found, skipping init"
fi

exec gaiad "$@" --home "${DAEMON_HOME}"
