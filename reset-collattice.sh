#!/usr/bin/env bash
set -Eeuo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-collattice}"
DATA_DIR="${DATA_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/collattice}"
DB_PATH="${DB_PATH:-${DATA_DIR}/collattice.db}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--reset-db [--yes]] [--help]

Stops the container, removes the SQLite database (and its -wal/-shm files),
then starts the container again so the app recreates its first-run state.
Asks for confirmation unless --yes is given.

Environment variables:
  CONTAINER_NAME  Docker container name (default: collattice)
  DATA_DIR        Host directory containing the SQLite DB (default: ./collattice)
  DB_PATH         Full path to the database file (default: DATA_DIR/collattice.db)
EOF
}

reset_db() {
  if [[ "${1:-}" != "--yes" ]]; then
    read -r -p "This permanently deletes ${DB_PATH}. Continue? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
  fi

  local exists=false
  if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
    exists=true
    echo "Stopping container '$CONTAINER_NAME'..."
    docker stop "$CONTAINER_NAME" >/dev/null
  fi

  if compgen -G "${DB_PATH}*" >/dev/null; then
    echo "Removing database: ${DB_PATH} (including -wal/-shm files)"
    rm -f "$DB_PATH" "${DB_PATH}-wal" "${DB_PATH}-shm"
  else
    echo "Database not found: $DB_PATH"
  fi

  if [[ "$exists" == true ]]; then
    echo "Starting container '$CONTAINER_NAME'..."
    docker start "$CONTAINER_NAME" >/dev/null
  else
    echo "Container '$CONTAINER_NAME' does not exist; nothing to start."
  fi
}

case "${1:-}" in
  --reset-db)
    reset_db "${2:-}"
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    echo "Unknown command: ${1:-}" >&2
    usage >&2
    exit 1
    ;;
esac
