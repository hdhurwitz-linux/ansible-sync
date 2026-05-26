#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT_SCRIPT="$SCRIPT_DIR/extract_joplin_secrets.py"
ENV_FILE="$HOME/.config/ai-secrets/env"
VAULT_FILE="$HOME/ansible-sync/group_vars/all/vault_secrets.yml"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { echo "ERROR: $*" >&2; return 1; }

# Ensure directory exists
mkdir -p "$HOME/.config/ai-secrets" "$(dirname "$VAULT_FILE")"

log "Extracting secrets from Joplin..."
SECRETS_JSON=$($EXTRACT_SCRIPT json 2>/dev/null) || error "Failed to extract secrets"

# Validate we got secrets
if [[ -z "$SECRETS_JSON" ]] || [[ "$SECRETS_JSON" == "{}" ]]; then
    error "No secrets extracted from Joplin"
fi

log "Syncing to ~/.config/ai-secrets/env..."
$EXTRACT_SCRIPT env > "$ENV_FILE.tmp"
chmod 600 "$ENV_FILE.tmp"
mv "$ENV_FILE.tmp" "$ENV_FILE"
log "✅ Env file updated: $ENV_FILE"

# Only sync to GNOME Keyring on Linux (check for XDG_CURRENT_DESKTOP)
if [[ "${XDG_CURRENT_DESKTOP:-}" == *"GNOME"* ]]; then
    log "Syncing to GNOME Keyring..."
    
    # Check if secret-tool is available
    if ! command -v secret-tool &>/dev/null; then
        log "⚠️  secret-tool not found, skipping GNOME Keyring sync"
    else
        echo "$SECRETS_JSON" | python3 -c "
import json, sys, subprocess
secrets = json.load(sys.stdin)
for key, value in sorted(secrets.items()):
    try:
        # Store in GNOME Keyring with label
        subprocess.run([
            'secret-tool', 'store',
            '--label', f'HDH: {key}',
            'vault', 'joplin',
            'key', key
        ], input=value.encode(), check=True, capture_output=True)
        print(f'  ✓ {key}')
    except Exception as e:
        print(f'  ⚠ {key}: {e}', file=sys.stderr)
" || log "⚠️  Some secrets failed to store in GNOME Keyring"
    fi
else
    log "⚠️  Not running on GNOME desktop (XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP)"
fi

# Sync to Ansible Vault YAML
log "Syncing to Ansible Vault ($VAULT_FILE)..."
$EXTRACT_SCRIPT yaml > "$VAULT_FILE.tmp"
chmod 600 "$VAULT_FILE.tmp"
mv "$VAULT_FILE.tmp" "$VAULT_FILE"
log "✅ Ansible Vault updated: $VAULT_FILE"

log "✅ All secret stores synchronized from Joplin"
