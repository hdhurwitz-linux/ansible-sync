#!/usr/bin/env bash
# Run this on any new machine to bootstrap ansible-pull from Coordinator
set -euo pipefail

REPO_URL="https://github.com/hdhurwitz-linux/ansible-sync.git"
PLAYBOOK="playbooks/site.yml"
VAULT_PASS_FILE="$HOME/.config/ansible-sync/vault-pass.txt"

echo "[1/4] Check dependencies..."
command -v ansible-pull || sudo dnf install -y ansible || sudo apt-get install -y ansible

echo "[2/4] Configure vault password..."
if [[ ! -f "$VAULT_PASS_FILE" ]]; then
  mkdir -p "$HOME/.config/ansible-sync"
  echo "VAULT_PASS_REQUIRED=true"
  echo "Copy .vault_pass from Coordinator: scp HDH@100.x.x.x:~/ansible-sync/.vault_pass $VAULT_PASS_FILE"
  echo "Or paste it here: "
  read -rs vault_pass
  echo "$vault_pass" > "$VAULT_PASS_FILE"
  chmod 600 "$VAULT_PASS_FILE"
fi

echo "[3/4] Running ansible-pull..."
ansible-pull \
  --url "$REPO_URL" \
  --directory /tmp/ansible-sync-pull \
  --vault-password-file "$VAULT_PASS_FILE" \
  "$PLAYBOOK"

echo "[4/4] Bootstrap complete!"
