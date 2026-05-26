#!/usr/bin/env python3
"""
Extract secrets from Joplin database and output as key=value pairs.
Searches for notes with 'LocalVault:' prefix or 'API Token', 'API Key' titles.
"""

import sqlite3
import os
import sys
import json
from pathlib import Path

JOPLIN_DB = Path.home() / ".config/joplin-desktop/database.sqlite"
VAULT_PREFIXES = ["LocalVault:", "API Token", "API Key", "secret", "GITHUB", "OPENAI", "ANTHROPIC"]

def extract_joplin_secrets():
    """Extract key=value pairs from Joplin database."""
    if not JOPLIN_DB.exists():
        print(f"ERROR: Joplin database not found at {JOPLIN_DB}", file=sys.stderr)
        return {}

    secrets = {}
    try:
        conn = sqlite3.connect(str(JOPLIN_DB))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        # Query notes that look like secrets
        cursor.execute("""
            SELECT title, body FROM notes 
            WHERE is_conflict = 0 
            AND deleted_time = 0
            AND title LIKE 'LocalVault:%'
            ORDER BY title
        """)

        for row in cursor.fetchall():
            title = row['title'].strip()
            body = row['body'].strip() if row['body'] else ""

            # Parse title: "LocalVault: VoyageApiKey" → VOYAGE_API_KEY
            if title.startswith("LocalVault:"):
                var_name_raw = title.replace("LocalVault:", "").strip()
                # Convert CamelCase to SNAKE_CASE
                var_name = "".join(
                    "_" + c if c.isupper() and i > 0 else c
                    for i, c in enumerate(var_name_raw)
                ).upper()
            else:
                continue

            # Parse body: skip comment line, get first actual value
            # Format: "# LocalVault: KeyName\n\nactual_secret_value\n_Last synced:..."
            lines = [l.strip() for l in body.split('\n') if l.strip()]
            secret_value = None
            
            for line in lines:
                # Skip metadata/comment lines
                if line.startswith("#") or line.startswith("_") or line.startswith("**"):
                    continue
                # This is the secret value
                secret_value = line
                break

            if var_name and secret_value:
                # Skip obviously non-secret content
                if len(secret_value) < 5 or secret_value.lower() in ("none", "todo", "pending"):
                    continue
                secrets[var_name] = secret_value

        conn.close()
    except Exception as e:
        print(f"ERROR: Failed to read Joplin database: {e}", file=sys.stderr)
        return {}

    return secrets

def format_env_file(secrets):
    """Format secrets as shell-compatible env file."""
    lines = ["#!/usr/bin/env bash", "# Auto-generated from Joplin vault — do NOT edit manually\n"]
    for key in sorted(secrets.keys()):
        # Escape quotes in values
        value = secrets[key].replace('"', '\\"')
        lines.append(f'export {key}="{value}"')
    return "\n".join(lines)

def format_yaml_vault(secrets):
    """Format secrets as Ansible vault YAML."""
    lines = ["# yamllint disable", "---", "# Auto-generated from Joplin vault — do NOT edit manually\n"]
    for key in sorted(secrets.keys()):
        # Escape quotes in YAML
        value = secrets[key].replace('"', '\\"')
        lines.append(f"{key}: \"{value}\"")
    return "\n".join(lines)

def main():
    secrets = extract_joplin_secrets()

    if not secrets:
        print("WARNING: No secrets found in Joplin database", file=sys.stderr)
        return 1

    output_format = sys.argv[1] if len(sys.argv) > 1 else "env"

    if output_format == "env":
        print(format_env_file(secrets))
    elif output_format == "yaml":
        print(format_yaml_vault(secrets))
    elif output_format == "json":
        print(json.dumps(secrets, indent=2))
    else:
        # Default: key=value pairs (for secret-tool, etc.)
        for key in sorted(secrets.keys()):
            print(f"{key}={secrets[key]}")

    return 0

if __name__ == "__main__":
    sys.exit(main())
