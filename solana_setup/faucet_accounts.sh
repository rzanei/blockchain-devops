#!/bin/bash

# Configuration
ACCOUNTS=${1:-5}  # Default to 5 accounts
AMOUNT=${2:-100}  # Default to 100 SOL per account
KEYPAIR_DIR="$HOME/.solana-keypair"
GENESIS_ACCOUNT_PATH="$KEYPAIR_DIR/account0"
HOST="localhost"
RPC_PORT=8899

if ! command -v solana &> /dev/null; then
    echo "❌ solana CLI not found. Please install the Solana CLI."
    echo "Run: sh -c \"\$(curl -sSfL https://release.solana.com/stable/install)\""
    exit 1
fi

# Check if genesis account keypair exists
if [ ! -f "$GENESIS_ACCOUNT_PATH/keypair" ]; then
    echo "❌ Genesis account keypair not found at $GENESIS_ACCOUNT_PATH/keypair"
    exit 1
fi

# Set Solana configuration
if ! solana config set --keypair "$GENESIS_ACCOUNT_PATH/keypair" --url "http://$HOST:$RPC_PORT" 2>/dev/null; then
    echo "❌ Failed to set Solana configuration"
    exit 1
fi

# Verify validator is responding
for i in {1..10}; do
    CURL_OUTPUT=$(curl -s -w "%{http_code}" -o /dev/null "http://$HOST:$RPC_PORT" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}')
    if [ "$CURL_OUTPUT" -eq 200 ]; then
        echo "✅ Validator is responding on http://$HOST:$RPC_PORT (getHealth)"
        break
    fi
    CURL_OUTPUT=$(curl -s -w "%{http_code}" -o /dev/null "http://$HOST:$RPC_PORT" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"getVersion"}')
    if [ "$CURL_OUTPUT" -eq 200 ]; then
        echo "✅ Validator is responding on http://$HOST:$RPC_PORT (getVersion)"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "❌ Solana test validator is not responding on http://$HOST:$RPC_PORT after 10 attempts. Last HTTP status: $CURL_OUTPUT"
        exit 1
    fi
    echo "⏳ Retrying validator check ($i/10)..."
    sleep 2
done

# Fund accounts with SOL
echo "💸 Funding generated accounts with SOL from the source wallet..."
for ((i=1; i<=ACCOUNTS; i++)); do
    PUBLIC_KEY=$(cat "$KEYPAIR_DIR/account$i/public_key.json" 2>/dev/null)
    if [ -z "$PUBLIC_KEY" ]; then
        echo "❌ Public key for account $i not found at $KEYPAIR_DIR/account$i/public_key.json"
        continue
    fi
    echo "💵 Funding Account $i with Public Key: $PUBLIC_KEY 🗝️"
    for j in {1..3}; do
        if solana transfer "$PUBLIC_KEY" $AMOUNT --keypair "$GENESIS_ACCOUNT_PATH/keypair" --allow-unfunded-recipient --url "http://$HOST:$RPC_PORT" 2>/dev/null; then
            echo "✅ Account $i funded with $AMOUNT SOL"
            break
        fi
        if [ $j -eq 3 ]; then
            echo "❌ Failed to fund account $i after 3 attempts"
        else
            echo "⏳ Retrying transfer for account $i ($j/3)..."
            sleep 2
        fi
    done
done

echo "🎉 Account funding complete!"