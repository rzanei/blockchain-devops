#!/bin/bash
# Supervisor for Akash node — keeps pod alive for debugging if startup fails
set -Euo pipefail

echo "🔁 Persistent Akash Node Supervisor"

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
  echo "🚀 Starting Akash Validator..."
  /usr/local/bin/akash_start.sh &
  child=$!

  # Temporarily disable 'e' to allow child to exit with non-zero without killing supervisor
  set +e
  wait "$child"
  EXIT_CODE=$?
  set -e

  echo "❌ Akash exited with code $EXIT_CODE."
  echo "🕒 Sleeping for 10 minutes to allow manual debugging (container remains up)..."
  echo "   You can exec into the pod now to inspect logs or fix configuration."
  echo "$EXIT_CODE" > /tmp/akash.exit

  # Keep container alive for 10 minutes — perfect for debugging in Kubernetes
  sleep 600
done