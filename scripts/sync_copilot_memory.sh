#!/usr/bin/env bash
# Sync Copilot memories + chat history across machines via notes-workspace repo.
# - Pull latest shared state
# - Publish this machine's memories/chat snapshot
# - Commit + push changes
# - Pull shared memory into local memory-tool folder

set -euo pipefail

HOST="${HOSTNAME:-$(hostname -s)}"
USER_HOME="${HOME}"
REPO_URL="${COPILOT_MEMORY_REPO_URL:-https://github.com/hdhurwitz-linux/notes-workspace.git}"
REPO_DIR="${COPILOT_MEMORY_REPO_DIR:-${USER_HOME}/Projects/notes-workspace}"
LOCAL_MEM_DIR="${USER_HOME}/.config/Code/User/globalStorage/github.copilot-chat/memory-tool/memories"
LOCAL_CHAT_DB="${USER_HOME}/.config/Code/User/globalStorage/github.copilot-chat/session-store.db"
MACHINE_ROOT="${REPO_DIR}/copilot-memory/machines/${HOST}"
MACHINE_MEM_DIR="${MACHINE_ROOT}/memories"
MACHINE_CHAT_DIR="${MACHINE_ROOT}/chat"
SHARED_DIR="${REPO_DIR}/copilot-memory/shared"
LOCAL_SHARED_DIR="${LOCAL_MEM_DIR}/fleet-shared"
TS="$(date +%Y%m%d_%H%M%S)"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

mkdir -p "${USER_HOME}/Projects"

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  log "Cloning notes-workspace..."
  git clone "${REPO_URL}" "${REPO_DIR}" >/dev/null 2>&1
fi

cd "${REPO_DIR}"
log "Pulling latest shared memory..."
git pull origin main --rebase >/dev/null 2>&1 || true

mkdir -p "${MACHINE_MEM_DIR}" "${MACHINE_CHAT_DIR}" "${SHARED_DIR}" "${LOCAL_SHARED_DIR}"

# Publish this machine memories
if [[ -d "${LOCAL_MEM_DIR}" ]]; then
  rsync -a --delete --exclude 'fleet-shared/' "${LOCAL_MEM_DIR}/" "${MACHINE_MEM_DIR}/"
fi

# Snapshot chat history DB without locking issues
if [[ -f "${LOCAL_CHAT_DB}" ]]; then
  if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "${LOCAL_CHAT_DB}" ".backup '${MACHINE_CHAT_DIR}/session-store-${TS}.db'" >/dev/null 2>&1 || cp "${LOCAL_CHAT_DB}" "${MACHINE_CHAT_DIR}/session-store-${TS}.db"
  else
    cp "${LOCAL_CHAT_DB}" "${MACHINE_CHAT_DIR}/session-store-${TS}.db"
  fi
  # Retain latest 10 snapshots per machine
  ls -t "${MACHINE_CHAT_DIR}"/session-store-*.db 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
fi

# Build shared index for collective visibility
{
  echo "# Copilot Memory Fleet Index"
  echo
  echo "Updated: $(date -Is)"
  echo
  for d in "${REPO_DIR}"/copilot-memory/machines/*; do
    [[ -d "$d" ]] || continue
    m="$(basename "$d")"
    mem_count=$(find "$d/memories" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    chat_count=$(find "$d/chat" -maxdepth 1 -type f -name 'session-store-*.db' 2>/dev/null | wc -l | tr -d ' ')
    echo "- ${m}: memories=${mem_count}, chat_snapshots=${chat_count}"
  done
} > "${SHARED_DIR}/fleet-index.md"

# Pull shared memory down to local machine
rsync -a --delete "${SHARED_DIR}/" "${LOCAL_SHARED_DIR}/"

# Commit + push if changed
if [[ -n "$(git status --porcelain)" ]]; then
  git add copilot-memory/
  git commit -m "memory-sync(${HOST}): update memories/chat ${TS}" >/dev/null 2>&1 || true
  git push origin main >/dev/null 2>&1 || true
  log "Pushed memory sync updates."
else
  log "No memory changes to push."
fi

log "Memory sync complete."
