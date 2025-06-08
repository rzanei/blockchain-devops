#!/bin/bash
set -e

echo "🔁 Persistent Secret Node Supervisor"

trap 'echo "🛑 SIGTERM received, stopping..."; kill -TERM "$child"; wait "$child"; exit 0' SIGTERM

while true; do
  echo "🚀 Starting Secret Validator..."
  /usr/local/bin/secret_start.sh &
  child=$!

  wait "$child"
  EXIT_CODE=$?

  echo "❌ Secret exited with code $EXIT_CODE. Restarting in 10 seconds..."
  sleep 10
done
