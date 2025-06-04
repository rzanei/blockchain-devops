#!/bin/bash
set -e

echo "🔁 Persistent Akash Node Supervisor"

trap 'echo "🛑 SIGTERM received, stopping..."; kill -TERM "$child"; wait "$child"; exit 0' SIGTERM

while true; do
  echo "🚀 Starting Akash Validator..."
  /usr/local/bin/akash_start.sh &
  child=$!

  wait "$child"
  EXIT_CODE=$?

  echo "❌ Akash exited with code $EXIT_CODE. Restarting in 10 seconds..."
  sleep 10
done
