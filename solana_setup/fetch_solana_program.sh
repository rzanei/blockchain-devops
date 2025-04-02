#!/bin/bash

# Usage: ./fetch_solana_program.sh metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s
# Currently only supports 'metaplex_token_metadata'

PROGRAM_ID=${1:?Program Pub Key is required}

DEST_DIR="${HOME}/.blockchain-devops/solana/solana-fetched-programs"
mkdir -p "${DEST_DIR}"

case "${PROGRAM_ID}" in
  "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s")
    OUT_FILE="${DEST_DIR}/metaplex_token_metadata_program.so"

    echo "🔍 Fetching Metaplex Token Metadata program from mainnet..."
    solana program dump "${PROGRAM_ID}" "${OUT_FILE}" --url https://api.mainnet-beta.solana.com

    if [ $? -eq 0 ]; then
      echo "✅ Program dumped to ${OUT_FILE}"
    else
      echo "❌ Failed to fetch program, program not deployed in Mainnet."
      exit 1
    fi
    ;;
  *)
    echo "❌ Unsupported program with ID: ${PROGRAM_ID}"
    exit 1
    ;;
esac
