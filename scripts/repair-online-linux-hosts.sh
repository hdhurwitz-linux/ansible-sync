#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="$REPO_DIR/inventory/hosts.yml"

cd "$REPO_DIR"

echo "[1/5] Discover reachable linux_machines..."
ping_output=$(timeout 120 ansible linux_machines -i "$INVENTORY" -m ping --timeout=12 -o 2>&1 || true)
echo "$ping_output"
reachable_hosts=$(echo "$ping_output" | awk '/SUCCESS/ {print $1}' | paste -sd, -)

if [[ -z "${reachable_hosts:-}" ]]; then
  echo "No reachable linux_machines found."
  exit 0
fi

echo "Reachable hosts: $reachable_hosts"

echo "[2/5] Seed canonical vault password file..."
ansible-playbook -i "$INVENTORY" playbooks/seed_vault_pass.yml -l "$reachable_hosts"

echo "[3/5] Repair pull-runner and vault path wiring..."
ansible-playbook -i "$INVENTORY" playbooks/configure_pull_runner.yml -l "$reachable_hosts"

echo "[4/5] Repair Matrix Element keyring integration..."
ansible-playbook -i "$INVENTORY" playbooks/configure_matrix_element_keyring.yml -l "$reachable_hosts"

echo "[5/5] Run full sync on reachable hosts..."
ansible-playbook -i "$INVENTORY" playbooks/full_sync.yml -l "$reachable_hosts"

echo "Online host repair completed successfully."
