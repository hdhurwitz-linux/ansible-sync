#!/usr/bin/env bash
set -euo pipefail

echo "== Ensure cloud packages are installed =="
sudo dnf -y install rclone megasync megatools

echo "== Current rclone remotes =="
rclone listremotes || true

echo
cat <<'MSG'
Now configure these remotes in rclone (interactive):
  1) mega               (type: mega)
  2) onedrive-personal  (type: onedrive)
  3) protondrive        (type: protondrive)
  4) iclouddrive        (type: iclouddrive)

Run:
  rclone config

After remotes are created, start mounts:
  systemctl --user restart rclone-mount@mega.service
  systemctl --user restart rclone-mount@onedrive-personal.service
  systemctl --user restart rclone-mount@protondrive.service
  systemctl --user restart rclone-mount@iclouddrive.service

Check status:
  systemctl --user --no-pager --full status rclone-mount@mega.service
  systemctl --user --no-pager --full status rclone-mount@onedrive-personal.service
  systemctl --user --no-pager --full status rclone-mount@protondrive.service
  systemctl --user --no-pager --full status rclone-mount@iclouddrive.service
MSG
