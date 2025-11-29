#!/usr/bin/env bash
# shellcheck disable=SC2317

set -euo pipefail

# Wait for persistent volume to mount (Akash sometimes delays)
sleep 5
echo "Waited for mount – checking persistent dir: $HOME/.akash (exists: $([ -d "$HOME/.akash" ] && echo yes || echo no))"

# === AUTO DETECT FIRST RUN IN CONTAINER ===
if [[ ! -d "$HOME/.akash/data" || -z "$(ls -A "$HOME/.akash/data" 2>/dev/null)" ]]; then
    export INIT_NODE=true
    echo "First run detected (empty data dir) → forcing INIT_NODE=true"
else
    export INIT_NODE=false
    echo "Data directory exists → normal start (INIT_NODE=false)"
fi

# ──────────────────────────────────────────────────────────────
# BASIC CONFIG
# ──────────────────────────────────────────────────────────────
TARGET="akash"
HOMEDIR="$HOME/.${TARGET}"
CHAINID="akashnet-2"
KEYRING="file"
MONIKER="TheDigitalEmpire"
DENOM="uakt"

GENESIS="$HOMEDIR/config/genesis.json"
CONFIG="$HOMEDIR/config/config.toml"
APP="$HOMEDIR/config/app.toml"

GENESIS_URL="${GENESIS_URL:-https://snapshots.polkachu.com/genesis/akash/genesis.json}"
SNAP_FILE="$HOMEDIR/snapshot_akash.tar.lz4"
SNAP_CHECKSUM_URL=""
SNAP_URL_FILE="$HOMEDIR/.snap_url"

# Persistent peers
PERSISTENT_PEERS="${PERSISTENT_PEERS:-\
b3d4c223f832a6582be431060efb2a73903dc85b@85.237.193.106:26656,\
66b74927d51888a25fe94bff2dfeaae125739f26@79.127.196.36:29656}"

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
# AUTO-FETCH LATEST SNAPSHOT URL (multi-fallback)
# ──────────────────────────────────────────────────────────────
fetch_latest_snapshot() {
  local chain="akash"
  local base_url="https://snapshots.polkachu.com/snapshots/$chain"
  local page_url="https://www.polkachu.com/tendermint_snapshots/$chain"
  local rpc_url="https://akash-rpc.polkachu.com:443"

  log "Fetching latest snapshot for $chain (multi-fallback)..."

  # ---- 1. Try page scrape -------------------------------------------------
  log "Attempting page scrape from $page_url"
  if curl -fsSL --retry 1 --max-time 5 "$page_url" >/dev/null 2>&1; then
    log "Page accessible – scraping..."
    local html_page
    html_page=$(curl -fsSL --retry 2 "$page_url" 2>&1) || { err "Failed to fetch page: $page_url"; return 1; }
    local latest_height
    latest_height=$(echo "$html_page" | grep -o 'akash_[0-9]\+\.tar\.lz4' |
                    sed -E 's/akash_([0-9]+)\.tar\.lz4/\1/' | sort -nr | head -1)
    if [[ -n "$latest_height" && "$latest_height" =~ ^[0-9]+$ ]]; then
      local candidate_url="$base_url/akash_${latest_height}.tar.lz4"
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
      err "No valid height in page scrape"
    fi
  else
    err "Page inaccessible – falling back to RPC..."
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
    local test_url="$base_url/akash_${height}.tar.lz4"
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

# ──────────────────────────────────────────────────────────────
# RE-USE LOGIC (enhanced for resume)
# ──────────────────────────────────────────────────────────────
reuse_snapshot_if_possible() {
  log "Checking for existing snapshot reuse..."
  if [ -f "$SNAP_FILE" ]; then
    if lz4 -t "$SNAP_FILE" 2>/dev/null; then
      log "Existing snapshot is intact – RE-USING $SNAP_FILE"
      return 0
    else
      err "Existing snapshot corrupted – removing and will download new"
      rm -f "$SNAP_FILE"
    fi
  fi
  log "No usable SNAP_FILE – will download new"
}

# ──────────────────────────────────────────────────────────────
# 1. FIRST-TIME INITIALISATION (only if INIT_NODE=true)
# ──────────────────────────────────────────────────────────────
if [ "$INIT_NODE" = true ]; then
  log "INIT_NODE=true: Proceeding with node initialization..."
  mkdir -p "$HOMEDIR/config"

  # Decide final SNAP_URL
  log "Determining SNAP_URL..."
  if [ -n "${SNAP_URL:-}" ]; then
    log "Manual SNAP_URL supplied: $SNAP_URL"
    SNAP_CHECKSUM_URL="${SNAP_URL}.sha256"
  else
    fetch_latest_snapshot || die "Failed to fetch latest snapshot URL"
  fi
  log "Using SNAP_URL: $SNAP_URL"

  # Check if previous URL matches (for resume)
  if [ -f "$SNAP_URL_FILE" ]; then
    old_url=$(cat "$SNAP_URL_FILE")
    if [ "$old_url" != "$SNAP_URL" ]; then
      log "New snapshot URL detected – removing old partial file"
      rm -f "$SNAP_FILE"
    fi
  fi
  echo "$SNAP_URL" > "$SNAP_URL_FILE"

  # Reuse or download (with resume)
  reuse_snapshot_if_possible || die "Snapshot check failed"

  if [ ! -f "$SNAP_FILE" ] || ! lz4 -t "$SNAP_FILE" 2>/dev/null; then
    log "Starting/resuming snapshot download: $SNAP_URL (progress below)"
    curl -L --fail --retry 6 --retry-delay 5 --retry-max-time 60 --continue-at - --progress-bar -o "$SNAP_FILE" "$SNAP_URL" 2>&1 || { err "Snapshot download failed!"; die "Download aborted"; }
    log "Snapshot downloaded successfully"

    if [ -n "$SNAP_CHECKSUM_URL" ] && curl -fsI "$SNAP_CHECKSUM_URL" >/dev/null 2>&1; then
      log "Downloading checksum..."
      curl -fsSL -o "$SNAP_FILE.sha256" "$SNAP_CHECKSUM_URL" 2>&1 || { err "Checksum download failed"; rm -f "$SNAP_FILE"; die "Checksum aborted"; }
      log "Verifying checksum..."
      sha256sum -c "$SNAP_FILE.sha256" 2>&1 || { err "Checksum mismatch!"; rm -f "$SNAP_FILE" "$SNAP_FILE.sha256"; die "Snapshot corrupted – deleted"; }
      log "Checksum verified successfully"
    else
      log "No checksum URL available – skipping verification"
    fi
  else
    log "Snapshot already exists and intact – skipping download"
  fi

  # Validate LZ4 integrity
  log "Validating snapshot integrity (LZ4 test)..."
  lz4 -t "$SNAP_FILE" 2>&1 || { err "LZ4 integrity check failed!"; rm -f "$SNAP_FILE"; die "Invalid snapshot – deleted"; }
  log "Snapshot integrity validated"

  log "Initializing Akash node..."
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

  log "Resetting state..."
  $TARGET tendermint unsafe-reset-all --home "$HOMEDIR" --keep-addr-book 2>&1 || die "State reset failed"

  # ---- Extract with progress ---------------------------
  log "Starting snapshot extraction to $HOMEDIR... (verbose output below)"
  if command -v pv >/dev/null 2>&1; then
    log "Using pv for progress monitoring"
    pv "$SNAP_FILE" | lz4 -v -dc - | tar -xvf - -C "$HOMEDIR" 2>&1 || die "Extraction failed"
  else
    size=$(numfmt --to=iec-iB "$(stat -c %s "$SNAP_FILE")" 2>/dev/null || echo "$(stat -c %s "$SNAP_FILE") bytes")
    log "No pv installed – extracting (~$size) with verbose tar..."
    lz4 -v -dc "$SNAP_FILE" | tar -xvf - -C "$HOMEDIR" 2>&1 || die "Extraction failed"
  fi
  log "Extraction completed successfully"

  [ -f "$HOMEDIR/priv_validator_state.json.bak" ] && \
    { cp "$HOMEDIR/priv_validator_state.json.bak" "$HOMEDIR/data/priv_validator_state.json" 2>&1 || err "Failed to copy priv_validator_state"; } && \
    { rm "$HOMEDIR/priv_validator_state.json.bak" 2>&1 || err "Failed to remove priv_validator_state backup"; } || log "No priv_validator_state backup found – skipping restore"

  # Clean up snapshot after successful extraction to save space
  rm -f "$SNAP_FILE" "$SNAP_FILE.sha256" "$SNAP_URL_FILE"

  log "Node initialized – import your validator key if needed:"
  echo "   $TARGET keys add $MONIKER --recover --keyring-backend $KEYRING --home $HOMEDIR"
  echo "   Then re-run with INIT_NODE=false to start the node."
  exit 0
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
cfg_set minimum-gas-prices "0.025uakt" "$APP" || die "Config set failed"

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
log "Starting $TARGET... (FULL DEBUG LOGS BELOW)"
log "Watch for: SIGNED, COMMITTED, MINT, EXECUTED, CATCHING UP, and any errors"

exec "$TARGET" start \
  --home "$HOMEDIR" \
  --log_level "info" \
  --moniker "$MONIKER" \
  2>&1