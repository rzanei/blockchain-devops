#!/bin/bash
# Supervisor for Sentinel node — keeps pod alive for debugging if startup fails
set -Euo pipefail

echo "🔁 Persistent Sentinel Node Supervisor"

term() {
  echo "🛑 SIGTERM received, stopping..."
  if [[ -n "${child:-}" ]]; then
    kill -TERM "$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
  fi
  exit 0
}
trap term SIGTERM SIGINT

while true; do
  echo "🚀 Starting Sentinel Validator..."
  /usr/local/bin/sentinel_start.sh &
  child=$!

  # Allow non-zero exit codes from the child
  set +e
  wait "$child"
  EXIT_CODE=$?
  set -e

  echo "❌ Sentinel exited with code $EXIT_CODE."
  echo "🕒 Sleeping for 10 minutes to allow manual debugging (container remains up)..."
  echo "   You can exec into the pod now to inspect logs or fix configuration."
  echo "$EXIT_CODE" > /tmp/sentinel.exit

  # Keep container alive for 10 minutes instead of restarting immediately
  sleep 600
done
