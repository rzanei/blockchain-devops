Here's your **updated and professional `README.md` section** with Sentinel added and the note on Osmosis clarified:

---

# 🛠️ Blockchain DevOps

This repository contains scripts and configurations to automate the setup of blockchain nodes using Docker and containerization. The focus is on providing streamlined setups for the following blockchains:

* **Solana**
* **Evmos**
* **Akash**
* **Osmosis** *(🚧 Work in progress)*
* **Sentinel**

---

## 📁 Contents

* `Dockerfile.linux-ubuntu-base`: A base Dockerfile for creating a containerized environment based on Ubuntu.
* `evmos_setup/`: Contains the Docker Compose file and startup script for setting up an Evmos node.
* `solana_setup/`: Contains the Docker Compose file and startup script for setting up a Solana node.
* `akash_setup/`: Contains the Docker Compose file and startup script for setting up an Akash node.
* `osmosis_setup/`: Contains the Docker Compose file and startup script for setting up an Osmosis node.
* `sentinel_setup/`: Contains the Dockerfile, validator scripts, and full startup automation for SentinelHub.

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

### 2. How to Download a Binary

Use the provided `get-binary.sh` script to download the binary for the desired blockchain.

```bash
# Example usage
./get-binary.sh akash 0.38.4
./get-binary.sh kava 0.28.0
./get-binary.sh evmos 19.0.0
./get-binary.sh sentinel 0.11.5
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