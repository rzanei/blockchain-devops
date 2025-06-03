#!/bin/bash
set -e

echo "🚀 Starting Akash Validator..."

# Trap clean shutdown
trap 'echo "🛑 SIGTERM received, stopping..."; kill -TERM "$child"; wait "$child"; exit 0' SIGTERM

# Start the node process
/usr/local/bin/akash_start.sh &

child=$!
wait "$child"
