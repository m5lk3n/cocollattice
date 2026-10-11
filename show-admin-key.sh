#!/usr/bin/env bash
set -Eeuo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-collattice}"

usage() {
  cat <<EOF
Usage: $(basename "$0")

Prints the admin key from the Collattice container logs.
If the container was started with an explicit key (the image default
or ADMIN_KEY), the app may not log one; the image default is "cocollattice".

Environment variables:
  CONTAINER_NAME  Docker container name (default: collattice)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  usage
  exit 0
fi

if ! docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
  echo "Container '$CONTAINER_NAME' does not exist."
  exit 1
fi

echo "Admin key from logs:"
docker logs "$CONTAINER_NAME" 2>&1 | grep -Eo 'Admin auth key: .*' | tail -n 1 || {
  echo "No admin key found in logs. If none was set explicitly, the image default is 'cocollattice'."
  exit 1
}
