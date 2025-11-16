#!/usr/bin/env bash
# shellcheck disable=SC2317

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# BASIC CONFIG
# ──────────────────────────────────────────────────────────────
TARGET="sentinelhub"
HOMEDIR="$HOME/.${TARGET}"
CHAINID="sentinelhub-2"
KEYRING="file"
MONIKER="TheDigitalEmpire"
DENOM="udvpn"

GENESIS="$HOMEDIR/config/genesis.json"
CONFIG="$HOMEDIR/config/config.toml"
APP="$HOMEDIR/config/app.toml"

GENESIS_URL="${GENESIS_URL:-https://snapshots.polkachu.com/genesis/sentinel/genesis.json}"
SNAP_FILE="$HOME/snapshot.tar.lz4"
SNAP_CHECKSUM_URL=""
INIT_NODE="${INIT_NODE:-false}"

# Persistent peers
PERSISTENT_PEERS="${PERSISTENT_PEERS:-\
22d8779a7fa39c81ca457be8ea8e6d51bd886045@38.102.86.36:21056,\
65d87ee4d3a29cf7364a7a9889787c65ee70146c@23.227.221.173:26656,\
7766ec993ae96803834e15ef1e06ffbdf5d8257c@95.211.45.16:21056,\
c773ecc4fce799d3064b45cf6a9a13b28aaefa3d@88.205.101.202:26656,\
9e108fb71ce0749e9d874595bb8560d267c69789@35.228.251.58:26656,\
7a608cf632825669b69801f3b9917d660eab556c@185.148.1.181:26656,\
2b1ecb22f9c0da6e241075cf0e8f248d2e01e637@217.154.22.215:26656,\
c4dcd639a38688fb20b0c122eed5fb0cad02678a@217.154.22.215:26656,\
c9ce449ce1cbdbf857a30c3a88539ba63e7d29e8@151.115.88.82:26656,\
d1a31d3e2d5f5c9c9c9c9c9c9c9c9c9c9c9c9c9c@seed-1.sentinel.co:26656}"

# ──────────────────────────────────────────────────────────────
# Helper functions
# ──────────────────────────────────────────────────────────────
log() { echo -e "[\e[34m$(date +%H:%M:%S)\e[0m] $*"; }
err() { echo -e "[\e[31mERROR\e[0m] $*" >&2; }
die() { err "$*"; exit 1; }

cfg_set() {
  local key="$1" value="$2" file="$3" quote="${4:-true}"
  if [ ! -f "$file" ]; then
    err "Config file not found: $file"
    return 1
  fi
  if [ "$quote" = true ]; then
    value="\"$value\""
  fi
  if grep -q "^${key} *=" "$file" 2>/dev/null; then
    sed -i "s|^${key} *=.*|${key} = ${value}|" "$file"
  else
    printf '%s = %s\n' "$key" "$value" >> "$file"
  fi
}

# ──────────────────────────────────────────────────────────────
# Log initial configuration
# ──────────────────────────────────────────────────────────────
log "Starting script with configuration:"
log "  TARGET=$TARGET"
log "  HOMEDIR=$HOMEDIR (exists: $([ -d "$HOMEDIR" ] && echo yes || echo no))"
log "  CHAINID=$CHAINID"
log "  KEYRING=$KEYRING"
log "  MONIKER=$MONIKER"
log "  DENOM=$DENOM"
log "  GENESIS_URL=$GENESIS_URL"
log "  SNAP_FILE=$SNAP_FILE (exists: $([ -f "$SNAP_FILE" ] && echo yes || echo no))"
log "  INIT_NODE=$INIT_NODE (initial value)"
log "  PERSISTENT_PEERS=... (truncated)"

# ──────────────────────────────────────────────────────────────
# Check and adjust INIT_NODE
# ──────────────────────────────────────────────────────────────
log "Checking node initialization status..."
if [ -d "$HOMEDIR/data" ] && [ "$(ls -A "$HOMEDIR/data" 2>/dev/null)" ]; then
  log "Node data directory exists and is not empty – setting INIT_NODE=false to skip re-initialization"
  INIT_NODE=false
elif [ ! -d "$HOMEDIR/config" ]; then
  log "Config directory not found – forcing INIT_NODE=true for first-time setup"
  INIT_NODE=true
fi
log "Final INIT_NODE: $INIT_NODE"

# ──────────────────────────────────────────────────────────────
# AUTO-FETCH LATEST SNAPSHOT URL (multi-fallback)
# ──────────────────────────────────────────────────────────────
fetch_latest_snapshot() {
  local chain="sentinel"
  local base_url="https://snapshots.polkachu.com/snapshots/$chain"
  local page_url="https://www.polkachu.com/tendermint_snapshots/$chain"
  local rpc_url="https://sentinel-rpc.polkachu.com:443"

  log "Fetching latest snapshot for $chain (multi-fallback)..."

  # ---- 1. Try page scrape -------------------------------------------------
  log "Attempting page scrape from $page_url"
  if curl -fsSL --retry 1 --max-time 5 "$page_url" >/dev/null 2>&1; then
    log "Page accessible – scraping..."
    local html_page
    html_page=$(curl -fsSL --retry 2 "$page_url" 2>&1) || { err "Failed to fetch page: $page_url"; return 1; }
    local latest_height
    latest_height=$(echo "$html_page" | grep -o 'sentinel_[0-9]\+\.tar\.lz4' |
                    sed -E 's/sentinel_([0-9]+)\.tar\.lz4/\1/' | sort -nr | head -1)
    if [[ -n "$latest_height" && "$latest_height" =~ ^[0-9]+$ ]]; then
      local candidate_url="$base_url/sentinel_${latest_height}.tar.lz4"
      log "Candidate URL: $candidate_url – verifying accessibility..."
      if curl -fI --max-time 10 "$candidate_url" >/dev/null 2>&1; then
        SNAP_URL="$candidate_url"
        SNAP_CHECKSUM_URL="${SNAP_URL}.sha256"
        log "Scraped & verified: $SNAP_URL (height: $latest_height)"
        return 0
      else
        err "Candidate URL not found or inaccessible: $candidate_url"
      fi
    else
      err "No valid height found in page scrape"
    fi
  else
    err "Page blocked or inaccessible (HTTP error) – falling back to RPC..."
  fi

  # ---- 2. RPC + lag loop --------------------------------------------------
  log "Querying RPC for current height from $rpc_url..."
  local current_height
  current_height=$(curl -fsSL --retry 3 --max-time 10 \
    -d '{"jsonrpc":"2.0","method":"status","params":{},"id":1}' \
    "$rpc_url" 2>&1 | jq -r '.result.sync_info.latest_block_height // empty' | tr -d '[:space:]') || { err "RPC query failed: $rpc_url"; return 1; }

  [[ -n "$current_height" && "$current_height" =~ ^[0-9]+$ ]] ||
    { err "Unable to get chain height from RPC: got '$current_height'"; die "Invalid RPC response"; }

  log "Current RPC height: $current_height"

  local lags=(5000 6000 7000)
  for lag in "${lags[@]}"; do
    local height=$(( current_height - lag ))
    local test_url="$base_url/sentinel_${height}.tar.lz4"
    log "Checking height $height (lag $lag): $test_url"
    if curl -fI --max-time 10 "$test_url" >/dev/null 2>&1; then
      SNAP_URL="$test_url"
      SNAP_CHECKSUM_URL="${SNAP_URL}.sha256"
      log "Found snapshot: $SNAP_URL"
      return 0
    fi
    log "  → Height $height not found (404) – trying next lag"
  done
  die "No snapshot found in 5-7k lag range"
}

# -------------------------------------------------------------------------
# RE-USE LOGIC
# -------------------------------------------------------------------------
reuse_snapshot_if_possible() {
  log "Checking for existing snapshot reuse..."
  [[ -f "$SNAP_FILE" ]] || { log "No existing SNAP_FILE – will download new"; return 0; }

  local remote_name
  remote_name=$(basename "$SNAP_URL")
  local local_name
  local_name=$(basename "$SNAP_FILE")

  if [[ "$local_name" == "$remote_name" ]]; then
    log "Same snapshot name detected – RE-USING existing $SNAP_FILE"
    return 0
  else
    log "Different snapshot name – removing old $SNAP_FILE and will download new"
    rm -f "$SNAP_FILE" || { err "Failed to remove old snapshot"; return 1; }
  fi
}

# ──────────────────────────────────────────────────────────────
# 1. FIRST-TIME INITIALISATION (only if INIT_NODE=true)
# ──────────────────────────────────────────────────────────────
if [ "$INIT_NODE" = true ]; then
  log "INIT_NODE=true: Proceeding with node initialization..."

  # -------------------------------------------------------------------------
  # Decide final SNAP_URL
  # -------------------------------------------------------------------------
  log "Determining SNAP_URL..."
  if [ -n "${SNAP_URL:-}" ]; then
    log "Manual SNAP_URL supplied: $SNAP_URL"
    SNAP_CHECKSUM_URL="${SNAP_URL}.sha256"
  else
    fetch_latest_snapshot || die "Failed to fetch latest snapshot URL"
  fi
  log "Using SNAP_URL: $SNAP_URL"

  # Apply reuse logic
  reuse_snapshot_if_possible || die "Snapshot reuse check failed"

  log "Initializing Sentinel node..."

  log "Creating home directory: $HOMEDIR"
  mkdir -p "$HOMEDIR" || die "Failed to create home directory: $HOMEDIR"

  if [ ! -d "$HOMEDIR/config" ]; then
    log "Running node init: $TARGET init $MONIKER --chain-id $CHAINID --home $HOMEDIR"
    $TARGET init "$MONIKER" --chain-id "$CHAINID" --home "$HOMEDIR" 2>&1 || die "Node init failed"
  else
    log "Config directory already exists – skipping node init"
  fi

  # ---- Genesis -----------------------------------------------------------
  if [ ! -f "$GENESIS" ]; then
    log "Downloading genesis from: $GENESIS_URL"
    curl -fsSL --retry 5 --progress-bar -o "$GENESIS.tmp" "$GENESIS_URL" 2>&1 || die "Genesis download failed"
    mv "$GENESIS.tmp" "$GENESIS" || die "Failed to move genesis file"
    log "Genesis downloaded successfully"
  else
    log "Genesis file already exists: $GENESIS"
  fi

  # ---- Patch genesis -----------------------------------------------------
  log "Patching genesis.json..."
  jq '
    del(
      .app_state.vpn.nodes.params.inactive_duration,
      .app_state.vpn.sessions.params.inactive_duration,
      .app_state.vpn.subscriptions.params.inactive_duration
    )
    | .app_state.vpn.nodes.params.active_duration               //= "3600s"
    | .app_state.vpn.nodes.params.staking_share                 //= "0.100000000000000000"
    | .app_state.vpn.nodes.params.max_subscription_gigabytes    //= "10"
    | .app_state.vpn.nodes.params.max_subscription_hours        //= "10"
    | .app_state.vpn.nodes.params.min_subscription_gigabytes    //= "1"
    | .app_state.vpn.nodes.params.min_subscription_hours        //= "1"
    | .app_state.vpn.providers.params.staking_share             //= "0.100000000000000000"
    | .app_state.vpn.sessions.params.status_change_delay        //= "60s"
    | .app_state.vpn.subscriptions.params.status_change_delay   //= "120s"
    | .app_state.staking.params.min_commission_rate             //= "0.000000000000000000"

    | .app_state.gov.proposals |= map(
        (if has("content") then . + .content | del(.content) else . end)
        | with_entries(select(.key != "@type" and .key != "proposal_id" and .key != "description"
                           and .key != "title" and .key != "submit_time"
                           and .key != "voting_start_time" and .key != "voting_end_time"
                           and .key != "deposit_end_time"))
        | .final_tally_result = {yes: (.yes//"0"), abstain: (.abstain//"0"), no: (.no//"0")}
        | del(.no_with_veto)
      )
    | .app_state.gov.proposals |= map(select(has("changes") | not))

    | .app_state.gov.deposit_params = {
        min_deposit: (.app_state.gov.params.min_deposit // [{"denom":"udvpn","amount":"10000000"}]),
        max_deposit_period: (.app_state.gov.params.max_deposit_period // "172800s")
      }
    | .app_state.gov.voting_params = {voting_period: (.app_state.gov.params.voting_period // "172800s")}
    | .app_state.gov.tally_params = {
        quorum: (.app_state.gov.params.quorum // "0.334000000000000000"),
        threshold: (.app_state.gov.params.threshold // "0.500000000000000000"),
        veto_threshold: (.app_state.gov.params.veto_threshold // "0.334000000000000000")
      }
    | del(.app_state.gov.params)
  ' "$GENESIS" > "${GENESIS}.tmp" 2>&1 && mv "${GENESIS}.tmp" "$GENESIS" || die "Genesis patching failed"
  log "Genesis patched successfully"

  # ---- Download snapshot with progress -----------------------------------
  if [ ! -f "$SNAP_FILE" ]; then
    log "Starting snapshot download: $SNAP_URL (progress below)"
    curl -L --fail --retry 6 --retry-delay 5 --retry-max-time 60 \
         --progress-bar -o "$SNAP_FILE" "$SNAP_URL" 2>&1 || { err "Snapshot download failed! Check network or URL: $SNAP_URL"; die "Download aborted"; }
    log "Snapshot downloaded successfully"

    # ---- Checksum verification ---------------------------
    if [ -n "$SNAP_CHECKSUM_URL" ] && curl -fsI "$SNAP_CHECKSUM_URL" >/dev/null 2>&1; then
      log "Downloading checksum: $SNAP_CHECKSUM_URL"
      curl -fsSL -o "$SNAP_FILE.sha256" "$SNAP_CHECKSUM_URL" 2>&1 || { err "Checksum download failed"; rm -f "$SNAP_FILE"; die "Checksum aborted"; }
      log "Verifying checksum..."
      sha256sum -c "$SNAP_FILE.sha256" 2>&1 || { err "Checksum mismatch!"; rm -f "$SNAP_FILE" "$SNAP_FILE.sha256"; die "Snapshot corrupted – deleted"; }
      log "Checksum verified successfully"
    else
      log "No checksum URL available – skipping verification"
    fi
  else
    log "Snapshot already exists and matches: $SNAP_FILE – skipping download"
  fi

  # ---- Validate LZ4 integrity --------------------------------------------
  log "Validating snapshot integrity (LZ4 test)..."
  lz4 -t "$SNAP_FILE" 2>&1 || { err "LZ4 integrity check failed!"; rm -f "$SNAP_FILE"; die "Invalid snapshot – deleted"; }
  log "Snapshot integrity validated"

  log "Resetting state..."
  $TARGET tendermint unsafe-reset-all --home "$HOMEDIR" --keep-addr-book 2>&1 || die "State reset failed"

  # ---- Extract with progress ---------------------------
  log "Starting snapshot extraction to $HOMEDIR... (verbose output below)"
  if command -v pv >/dev/null 2>&1; then
    log "Using pv for progress monitoring"
    pv "$SNAP_FILE" | lz4 -v -dc - | tar -xvf - -C "$HOMEDIR" 2>&1 || die "Extraction failed"
  else
    local size=$(numfmt --to=iec-iB "$(stat -c %s "$SNAP_FILE")" 2>/dev/null || echo "$(stat -c %s "$SNAP_FILE") bytes")
    log "No pv installed – extracting (~$size) with verbose tar..."
    lz4 -v -dc "$SNAP_FILE" | tar -xvf - -C "$HOMEDIR" 2>&1 || die "Extraction failed"
  fi
  log "Extraction completed successfully"

  [ -f "$HOMEDIR/priv_validator_state.json.bak" ] && \
    { cp "$HOMEDIR/priv_validator_state.json.bak" "$HOMEDIR/data/priv_validator_state.json" 2>&1 || err "Failed to copy priv_validator_state"; } && \
    { rm "$HOMEDIR/priv_validator_state.json.bak" 2>&1 || err "Failed to remove priv_validator_state backup"; } || log "No priv_validator_state backup found – skipping restore"
else
  log "INIT_NODE=false: Skipping initialization (use INIT_NODE=true to force re-init)"
fi

# ──────────────────────────────────────────────────────────────
# 2. CONFIGURE NODE (runs every time)
# ──────────────────────────────────────────────────────────────
log "Applying node configuration..."

if [ ! -f "$CONFIG" ] || [ ! -f "$APP" ]; then
  die "Config files not found ($CONFIG or $APP). Run with INIT_NODE=true to initialize."
fi

ulimit -n 65535 2>/dev/null || err "Failed to set ulimit – continuing"
echo 1 | tee /proc/sys/vm/swappiness >/dev/null 2>&1 || err "Failed to set swappiness – continuing"

sed -i '/\[api\]/,/enable =/s/enable = .*/enable = true/' "$APP" 2>&1 || err "Failed to enable API"
sed -i '/\[api\]/,/enabled-unsafe-cors =/s/enabled-unsafe-cors = .*/enabled-unsafe-cors = true/' "$APP" 2>&1 || err "Failed to enable unsafe CORS"
sed -i '/\[grpc\]/,/enable =/s/enable = .*/enable = true/' "$APP" 2>&1 || err "Failed to enable gRPC"
sed -i '/\[grpc-web\]/,/enable =/s/enable = .*/enable = true/' "$APP" 2>&1 || err "Failed to enable gRPC-web"
sed -i 's|laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' "$CONFIG" 2>&1 || err "Failed to set laddr"

cfg_set storage.discard_abci_responses true "$CONFIG" false || die "Config set failed"
cfg_set iavl-disable-fastnode true "$APP" false || die "Config set failed"
cfg_set persistent_peers "$PERSISTENT_PEERS" "$CONFIG" || die "Config set failed"
cfg_set minimum-gas-prices "0.1udvpn" "$APP" || die "Config set failed"

cfg_set pruning "custom" "$APP" || die "Config set failed"
cfg_set pruning-keep-recent "100" "$APP" || die "Config set failed"
cfg_set pruning-keep-every "0" "$APP" || die "Config set failed"
cfg_set pruning-interval "10" "$APP" || die "Config set failed"
cfg_set snapshot-interval "0" "$APP" || die "Config set failed"
cfg_set snapshot-keep-recent "0" "$APP" || die "Config set failed"

sed -i 's/^log_level *=.*/log_level = "debug"/' "$CONFIG" 2>/dev/null ||
  printf 'log_level = "debug"\n' >> "$CONFIG" || err "Failed to set log_level in config"
log "Node log level set to debug for detailed output"

# ──────────────────────────────────────────────────────────────
# 3. START NODE – FULL LOGS VISIBLE
# ──────────────────────────────────────────────────────────────
if [ "$INIT_NODE" = true ]; then
  log "Node initialized – import your validator key if needed:"
  echo "   $TARGET keys add $MONIKER --recover --keyring-backend $KEYRING --home $HOMEDIR"
  echo "   Then re-run with INIT_NODE=false to start the node."
  exit 0
fi

log "Starting $TARGET... (FULL DEBUG LOGS BELOW)"
log "Watch for: SIGNED, COMMITTED, MINT, EXECUTED, CATCHING UP, and any errors"


"$TARGET" start \
  --home "$HOMEDIR" \
  --log_level "info" \
  --moniker "$MONIKER" \
  2>&1 || die "Node start failed – check above logs for errors"