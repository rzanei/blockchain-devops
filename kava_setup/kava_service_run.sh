#!/bin/bash
set -e

echo "🔁 Persistent Kava Node Supervisor"

trap 'echo "🛑 SIGTERM received, stopping..."; kill -TERM "$child"; wait "$child"; exit 0' SIGTERM

while true; do
  echo "🚀 Starting Kava Validator..."
  /usr/local/bin/kava_start.sh &
  child=$!

  wait "$child"
  EXIT_CODE=$?

  echo "❌ Kava exited with code $EXIT_CODE. Restarting in 10 seconds..."
  sleep 10
done
