#!/bin/sh
set -e
if [ "${INSTALL_TAURIC}" != "1" ]; then
  echo "Skipping TradingAgents install (INSTALL_TAURIC!=1)"
  exit 0
fi
# Prefer vendor checkout copied into image context; fall back to git clone.
if [ -d /opt/TradingAgents ]; then
  pip install --no-cache-dir -e /opt/TradingAgents || true
elif [ -d ./vendor/TradingAgents ]; then
  pip install --no-cache-dir -e ./vendor/TradingAgents || true
else
  echo "TradingAgents not present at build; runtime may mount /opt/TradingAgents"
fi
