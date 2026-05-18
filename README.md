# ansible-sync

Native Ansible workstation sync for secrets/config/AI state.

## Source of truth
- GitHub repo is the only source of truth for sync scripts/config.
- Every machine should run the same `ansible-sync-pull.timer` from this repo.

## Local runner (already enabled)
- Unit: `ansible-sync.service`
- Timer: `ansible-sync.timer` (every 15m with jitter)

## Cross-machine best practice
Use `ansible-pull` so each machine converges from the same Git repo.

1. Install pull-runner assets on a machine:
   ansible-playbook -i inventory playbooks/configure_pull_runner.yml
2. Copy env template:
   cp ~/.config/ansible-sync/pull.env.example ~/.config/ansible-sync/pull.env
3. Ensure repo URL/branch in `inventory/group_vars/all.yml` are correct:
   - `ansible_sync_repo_url`
   - `ansible_sync_repo_branch`
4. Re-run pull-runner setup so local `pull.env` is rendered from those values.
4. Ensure timer is active:
   systemctl --user daemon-reload
   systemctl --user enable --now ansible-sync-pull.timer

`ansible-sync-pull.service` runs `playbooks/full_sync.yml` so all machines execute the same sequence:
- build/update generated tailnet inventory
- converge apps/tooling
- converge future stack (agent/API/Postgres scaffolding)
- discover combined AI inventory across tailnet
- merge/apply AI secrets
- local state sync

## VS Code + Codespaces workflow (multi-machine)
- Repository includes `.devcontainer/devcontainer.json` for GitHub Codespaces.
- VS Code workspace wiring is preconfigured in `.vscode/`:
  - `extensions.json`: recommended extensions
  - `settings.json`: Ansible + terminal defaults
  - `tasks.json`: one-click tasks for inventory/sync/timer checks

Run from VS Code command palette (`Tasks: Run Task`):
- `Ansible: Build Tailnet Inventory`
- `Ansible: Configure Pull Runner`
- `Ansible: Full Sync (local)`
- `Ansible: Full Sync (all reachable Linux)`

## Manual run
ansible-playbook -i inventory playbooks/site.yml

## Notes
- PATH is managed via `~/.config/profile.d/10-managed-path.sh` and sourced from `.bashrc` and `.profile`.
- Consolidated output is written to `state/<hostname>/`.
