# Solana Setup

## Overview
`solana_setup` is a script-based setup for initializing a Solana test environment with necessary dependencies. This project simplifies the process of setting up a local Solana test validator, installing required dependencies, and funding accounts with a faucet.

## Installation
To install the necessary dependencies, run the `requirements.sh` script:
```sh
./requirements.sh
```
This script installs:
- 🔹 Rust (`rustc`)
- 🔹 Solana CLI
- 🔹 Anchor CLI
- 🔹 Node.js
- 🔹 Yarn

## Running the Solana Test Validator
Once the dependencies are installed, start the Solana test node by executing:
```sh
chmod +x solana_start.sh
./solana_start.sh
```
This initializes a local Solana test validator for development and testing purposes.

## Funding Accounts with Faucet
In a separate terminal, run the following command to provide funds to initialized accounts:
```sh
chmod +x solana_faucet.sh
./solana_faucet.sh
```
This step ensures that test accounts have sufficient SOL for transactions within the local test environment.

## Verifying the Setup
To check if Solana is running properly, use:
```sh
solana --version
```
To ensure the test validator is active, you can run:
```sh
solana cluster-version
```

## Additional Notes
- If you encounter permission errors, try running scripts with `sudo`.
- Ensure that your Rust and Solana installations are correctly configured by running:
  ```sh
  rustc --version
  solana --version
  ```
