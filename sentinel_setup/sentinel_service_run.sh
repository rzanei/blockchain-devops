#!/bin/bash
set -e

echo "🔁 Persistent Sentinel Node Supervisor"

trap 'echo "🛑 SIGTERM received, stopping..."; kill -TERM "$child"; wait "$child"; exit 0' SIGTERM

while true; do
  echo "🚀 Starting Sentinel Validator..."
  /usr/local/bin/sentinel_start.sh &
  child=$!

  wait "$child"
  EXIT_CODE=$?

  echo "❌ Sentinel exited with code $EXIT_CODE. Restarting in 10 seconds..."
  sleep 10
done
