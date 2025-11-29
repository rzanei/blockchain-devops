#!/bin/bash
set -euo pipefail

# ============================================================
# Akash / Cosmos provider sniper
#
# Creates a NEW deployment from chain-specific ./<chain>_setup/deploy.yaml
# then waits until a specific provider places an OPEN bid on it, and
# immediately snipes the lease.
#
# Usage examples:
#   ./akash-provider-sniper.sh akash
#   CHAIN_NAME=akash ./akash-provider-sniper.sh
#
# Args / env:
#   CHAIN_NAME       - REQUIRED (either as $1 or env).
#                      Used to:
#                        - pick chain config (CHAIN_ID, RPC, TARGET_PROVIDER)
#                        - locate SDL at "./${CHAIN_NAME}_setup/deploy.yaml"
#
# Chain-specific config is defined in the case "$CHAIN_NAME" block below.
# ============================================================

# -------- CHAIN SELECTION --------
CHAIN_NAME="${CHAIN_NAME:-${1-}}"

if [[ -z "${CHAIN_NAME:-}" ]]; then
  echo "ERROR: CHAIN_NAME is required." >&2
  echo "Usage: CHAIN_NAME=<name> $0  OR  $0 <name>" >&2
  exit 1
fi

# ========================= CONFIG =========================
KEY_NAME="thedigitalempire"

# Per-chain settings
case "$CHAIN_NAME" in
  akash)
    CHAIN_ID="akashnet-2"
    RPC="https://rpc.akashnet.net:443"
    # europlots provider on Akash
    TARGET_PROVIDER="akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc"
    ;;
  *)
    echo "Unknown CHAIN_NAME: $CHAIN_NAME" >&2
    exit 1
    ;;
esac

DEPLOY_YAML="./${CHAIN_NAME}_setup/deploy.yaml"

POLL_INTERVAL=4
GAS_FEES_LEASE="5000uakt"
GAS_FEES_OTHER="500uakt"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}" >&2; }
warn()  { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠ $1${NC}" >&2; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ✗ $1${NC}" >&2; }

ensure_certificate() {
    log "Checking client certificate..."
    local addr
    addr=$(provider-services keys show "$KEY_NAME" -a)
    log "Local address certificate on: $addr"
    
    if provider-services query cert list client "$addr" --node "$RPC" --output json 2>/dev/null \
        | jq -e '.certificates | length > 0' >/dev/null 2>&1; then
        log "Valid client certificate found"
        return
    fi

    log "Generating + publishing new client certificate..."
    provider-services tx cert generate client --from "$KEY_NAME" --overwrite -y >/dev/null
    sleep 8
    provider-services tx cert publish client \
        --from "$KEY_NAME" \
        --chain-id "$CHAIN_ID" \
        --node "$RPC" \
        --gas auto --gas-adjustment 1.5 \
        --fees "$GAS_FEES_OTHER" -y >/dev/null
    sleep 8
    log "Certificate ready"
}

create_deployment_and_get_dseq() {
    log "Creating NEW deployment from $DEPLOY_YAML ..."
    provider-services tx deployment create "$DEPLOY_YAML" \
        --from "$KEY_NAME" \
        --chain-id "$CHAIN_ID" \
        --node "$RPC" \
        --gas auto --gas-adjustment 1.5 \
        --fees "$GAS_FEES_OTHER" -y >/dev/null

    sleep 8

    local owner
    owner=$(provider-services keys show "$KEY_NAME" -a)

    local json
    json=$(provider-services query deployment list \
        --owner "$owner" \
        --node "$RPC" \
        --output json \
        --limit 20 2>/dev/null || echo '{}')

    local dseq
    dseq=$(echo "$json" \
        | jq -r '
            (.deployments // [])[]
            | .deployment.id.dseq // empty
        ' 2>/dev/null \
        | sort -nr \
        | head -n1)

    if [[ -z "$dseq" ]]; then
        error "Could not find DSEQ for newly created deployment"
        exit 1
    fi

    log "New deployment created with DSEQ = $dseq"
    echo "$dseq"
}

wait_for_target_bid() {
    local dseq=$1
    local owner
    owner=$(provider-services keys show "$KEY_NAME" -a)
    
    log "Monitoring bids on DSEQ $dseq for provider $TARGET_PROVIDER..."

    while true; do
        local json
        json=$(provider-services query market bid list \
            --owner "$owner" \
            --dseq "$dseq" \
            --node "$RPC" \
            --output json 2>/dev/null || echo '{}')

        local bid_count
        bid_count=$(echo "$json" | jq '
          [(.bids // [])[] | select(.bid.state == "open")] | length
        ' 2>/dev/null || echo 0)
        log "bid_count (open) for dseq $dseq = $bid_count"

        local providers
        providers=$(echo "$json" | jq -r '
          (.bids // [])[]
          | select(.bid.state == "open")
          | .bid.bid_id.provider // .bid.id.provider // "<no-provider-field>"
        ' 2>/dev/null || true)

        log "Current OPEN bid providers for dseq $dseq:"
        if [[ -n "$providers" ]]; then
            while IFS= read -r p; do
                [[ -n "$p" ]] && log "  provider: $p"
            done <<< "$providers"
        else
            log "  (none)"
        fi

        if (( bid_count == 0 )); then
            sleep "$POLL_INTERVAL"
            continue
        fi

        if echo "$json" | jq -e --arg p "$TARGET_PROVIDER" '
            (.bids // [])[]
            | select(.bid.state == "open")
            | select(
                .bid.bid_id.provider == $p
                or .bid.id.provider == $p
            )
        ' >/dev/null 2>&1; then
            log "TARGET PROVIDER HAS OPEN BID! SNIPING..."
            return 0
        fi

        (( bid_count > 0 )) && warn "$bid_count open bid(s) so far — waiting for target provider"
        sleep "$POLL_INTERVAL"
    done
}

create_lease_and_manifest() {
    local dseq=$1

    log "Creating lease with provider $TARGET_PROVIDER on DSEQ $dseq..."
    provider-services tx market lease create \
        --dseq "$dseq" \
        --provider "$TARGET_PROVIDER" \
        --from "$KEY_NAME" \
        --chain-id "$CHAIN_ID" \
        --node "$RPC" \
        --gas auto --gas-adjustment 1.5 \
        --fees "$GAS_FEES_LEASE" -y > /dev/null

    sleep 8

    cp "$DEPLOY_YAML" "${DEPLOY_YAML}.tmp"
    sed -i.bak "s|provider: .*|provider: $TARGET_PROVIDER|g" "${DEPLOY_YAML}.tmp" 2>/dev/null || true

    log "Sending manifest to $TARGET_PROVIDER..."
    provider-services send-manifest "${DEPLOY_YAML}.tmp" \
        --dseq "$dseq" \
        --provider "$TARGET_PROVIDER" \
        --from "$KEY_NAME" \
        --node "$RPC" -y >/dev/null

    log "SNIPED SUCCESSFULLY! DSEQ $dseq is now leased with $TARGET_PROVIDER 🚀"
}

main() {
    log "Starting sniper on chain: $CHAIN_NAME (CHAIN_ID=$CHAIN_ID, RPC=$RPC, SDL=$DEPLOY_YAML)"
    ensure_certificate

    while true; do
        DSEQ=$(create_deployment_and_get_dseq)
        wait_for_target_bid "$DSEQ"
        create_lease_and_manifest "$DSEQ"
        
        read -p "Create and snipe another deployment? [y/N]: " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || break
    done

    log "Sniper stopped."
}

main
