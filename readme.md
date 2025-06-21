Here's your **updated and professional `README.md` section** with Sentinel added and the note on Osmosis clarified:

---

# 🛠️ Blockchain DevOps

This repository contains scripts and configurations to automate the setup of blockchain nodes using Docker and containerization. The focus is on providing streamlined setups for the following blockchains:

* **Solana**
* **Evmos**
* **Akash**
* **Osmosis** *(🚧 Work in progress)*
* **Secret** *(🚧 Work in progress See branch Notes)*
* **Sentinel**

---

## 📁 Contents

* **`Dockerfile.linux-ubuntu-base`**: A base Dockerfile for creating a containerized environment based on Ubuntu, used across multiple node setups.

### 🧱 Network Setups

Each directory (`*_setup/`) contains the full automation stack required to deploy and operate a blockchain node in a reproducible and containerized way.

* **`evmos_setup/`**: Contains the Dockerfile, Akash deployment manifest, and scripts to set up and manage an **Evmos** node.
* **`solana_setup/`**: Contains the necessary files to deploy and run a **Solana** validator node.
* **`akash_setup/`**: Includes automation for setting up a **validator node on Akash**, including restake scripts and Akash-native deployment manifest.
* **`osmosis_setup/`**: *(🚧 Work in progress – not currently in active set)*.
* **`secret_setup/`**: *(🚧 Work in progress – see WIP branch)* — experimental support for **Secret Network**.
* **`sentinel_setup/`**: Complete Dockerized setup for **SentinelHub** validator on Cosmos SDK v0.47 (`v0.11.5`), including genesis patching and validator lifecycle automation.

---

## 📦 Folder File Structure

*(Applies to each `*_setup/` directory)*

| File                            | Description                                                                                |
| ------------------------------- | ------------------------------------------------------------------------------------------ |
| `.env`                          | Contains the `NODE_VERSION` used and tested for the binary.                                |
| `deploy.yaml`                   | Akash Network deployment manifest to launch the node as a containerized service.           |
| `Dockerfile.[network]`          | Dockerfile used to build the node image for deployment.                                    |
| `genesis.[chain].json`          | Genesis file compatible with the tested version (used for snapshot sync and validation).   |
| `[network]_restake.sh`          | Script used *inside the container* to withdraw and re-delegate validator rewards.          |
| `[network]_service_run.sh`      | Supervisor that runs the node in a loop, restarting it if it crashes.                      |
| `[network]_start.sh`            | Full startup logic: genesis patching, config tuning, snapshot extraction, and node launch. |
| `[network]_validator_create.sh` | Script to create a validator with configured commission, moniker, and delegation.          |

> **Note:** File prefixes like `sentinel_`, `akash_`, etc., vary depending on the blockchain.

---

## ✨ Features

* **Automated Node Setup**: Easily deploy blockchain nodes with Docker for Solana, Evmos, Akash, Osmosis, and Sentinel.
* **Scalable and Replicable**: Set up nodes that can be easily scaled or replicated across environments.
* **Customizable Dockerfile**: Build customized blockchain setups tailored to specific network needs.
* **Validator Lifecycle Support**: Includes validator creation, restake automation, and snapshot recovery where applicable.

---

## ✅ Prerequisites

Before you get started, make sure the following tools are installed on your machine:

* Docker (including Docker Compose)
* Git

---

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/rzanei/blockchain-devops.git
cd blockchain-devops
```

---

## 🔽 Binary Download Automation

Use the provided `get-binary.sh` script to download and extract the correct version of a node binary.

```bash
# Example usage
./get-binary.sh akash 0.38.4
./get-binary.sh kava 0.28.0
./get-binary.sh evmos 19.0.0
./get-binary.sh sentinel 0.11.5
```

> Binaries will be downloaded and extracted into:
>
> ```bash
> ~/.blockchain-devops/<node>-<version>/
> ```

### 📦 Supported Chains

* `akash`
* `osmosis`
* `evmos`
* `kava`
* `sentinel`

### 🛠️ Script Logic Overview (`get-binary.sh`)

The script automatically:

* Identifies the requested node and version.
* Downloads the binary (ZIP or TAR) from the official GitHub release.
* Extracts or unpacks it to a designated local directory.
* Makes the binary executable.

This ensures **reproducibility and portability** across environments or deployments.

---

## 🌐 Persistent Peer Checker

The `persistent-peer-checker.sh` script helps **validate and discover live, reachable peers** for a Cosmos SDK-based blockchain.

### ✅ What It Does

* Checks reachability (`IP:PORT`) for a list of known nodes.
* Verifies whether they serve Tendermint snapshots (via `/snapshots` endpoint).
* Outputs two lists:

  * **Working Peers** (can be used in `persistent_peers`)
  * **Snapshot-Capable Peers** (can be used for state sync)

### 🔁 Usage

```bash
./persistent-peer-checker.sh
```

### 📤 Output Example

```text
🔎 Checking peers...
8542cd...@seed.publicnode.com:26656 ✅ Reachable
   📦 Provides 3 snapshot(s)

...

==============================
✅ Usable Peers: 4
<joined_peer_list>

📦 Snapshot-Capable Peers: 2
<joined_snapshot_peers>
==============================
```

You can take the output from this script and paste it directly into your `config.toml` like:

```toml
persistent_peers = "peer1@ip1:port1,peer2@ip2:port2,..."
```

---

🌐 Connect & Collaborate
I'm open to collaboration! If you're looking for DevOps support for your validator infrastructure, testnets, node automation, or blockchain tooling, feel free to reach out.

📬 Contact
📧 Email: dev.rzanei@gmail.com

💬 [Telegram](https://t.me/TheRealFrame)

🌍 [Validator Website](https://thedigitalempire.xyz/)

🐦 [Twitter/X](https://x.com/therealframe_)

💻 [GitHub](https://github.dev/rzanei/)

👔 [LinkedIn](https://www.linkedin.com/in/rzanei-dev)

---