## Set Up a Fast local Development Environment

# Setup the solana Node
```bash
# launch the script generating 1O accounts in the $HOME/.solana-keypair folder  
./solana_start.sh 10

# Expected output
Config File: .../.config/solana/cli/config.yml
RPC URL: http://localhost:8899 
WebSocket URL: ws://localhost:8900/ (computed)
Keypair Path: .../.solana-keypair/account0/keypair 
Commitment: confirmed 
Ledger location: test-ledger

```

# Faucet the generated accounts
```bash
# this will transfer to all 10 accounts 200SOL as initial balance
./faucet_accounts.sh 10 200

# Expected output
Funding account 1 with public key: Gz4LzEzLnZErJU8Z9d3bb1siDtV5bY5DNRHj5vpDJKYv
Signature: 3Tou4DvWDDc46wdNXucZJS2FML7k4d6g1jaxSVkbW5WhYNGedhy3KYKQwkRM3QGcfe8u4he32o9bC2sK83z5XL4S
```
# Check the account balance
```bash
solana balance Gz4LzEzLnZErJU8Z9d3bb1siDtV5bY5DNRHj5vpDJKYv

# Expected output
200 SOL
```