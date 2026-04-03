#!/usr/bin/env bash
# Run ON the deployer server
# Installs Ansible and sets up SSH key for target connection
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Preparing deployer server ==="

# 1. Install Ansible
echo "[1/4] Installing Ansible..."
apt update
apt install -y ansible

echo "Ansible $(ansible --version | head -1) installed"

# 2. Extract target IP and build key filename
TARGET_IP=$(grep 'ansible_host' "$SCRIPT_DIR/inventory.yml" | awk '{print $2}')
TARGET_SUFFIX=$(echo "$TARGET_IP" | tr '.' '_')
KEY_PATH="/root/.ssh/id_ed25519_target_${TARGET_SUFFIX}"

echo "Target IP: $TARGET_IP"
echo "Key file: $KEY_PATH"

# 3. Generate SSH key (if not exists)
echo "[2/4] Checking SSH key..."
if [ ! -f "$KEY_PATH" ]; then
    echo "Generating new SSH key..."
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "deployer@${TARGET_IP}"
else
    echo "SSH key already exists: $KEY_PATH"
fi

# 4. Copy key to target
echo "[3/4] Copying SSH key to target..."

# Check existing connection
if ssh -o ConnectTimeout=5 -o BatchMode=yes -i "$KEY_PATH" root@"$TARGET_IP" "echo 'Connection works'" 2>/dev/null; then
    echo "SSH connection to target already configured"
else
    echo "Copying key (will need root password for target)..."
    ssh-copy-id -o StrictHostKeyChecking=no -i "${KEY_PATH}.pub" root@"$TARGET_IP"
fi

# 5. Verify connection via Ansible
echo "[4/4] Verifying connection via Ansible..."
ansible -i "$SCRIPT_DIR/inventory.yml" all -m ping

echo ""
echo "=== Deployer ready ==="
echo "Run setup: ./deploy.sh"
echo "Run basic only: ./deploy.sh basic"
