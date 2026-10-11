#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_NAME="${IMAGE_NAME:-collattice:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-collattice}"
HOST_PORT="${HOST_PORT:-8080}"
CONTAINER_PORT="${CONTAINER_PORT:-8080}"
DATA_DIR="${DATA_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.collattice-data}"
RESTART_POLICY="${RESTART_POLICY:-unless-stopped}"
RUN_AS="${RUN_AS:-$(id -u):$(id -g)}"

mkdir -p "$DATA_DIR"

usage() {
  cat <<EOF
Usage: $(basename "$0") {start|stop|restart|status}

Starts or stops the Collattice container.

Environment variables:
  IMAGE_NAME       Docker image tag to run (default: collattice:latest)
  CONTAINER_NAME    Container name (default: collattice)
  HOST_PORT         Host port to expose (default: 8080)
  CONTAINER_PORT    Container port (default: 8080)
  DATA_DIR         Host directory for the SQLite database (default: ./.collattice-data)
  RESTART_POLICY   Docker restart policy (default: unless-stopped; use no to disable auto-restart)
  RUN_AS           uid:gid to run the container as (default: the invoking user's, so files in DATA_DIR are owned by you)
  ADMIN_KEY        Admin auth key to pass to the container (default: the one baked into the image)

'restart' recreates the container, so it picks up a rebuilt image or a changed RUN_AS.
EOF
}

start_container() {
  if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
    echo "Container '$CONTAINER_NAME' already exists. Starting it..."
    docker update --restart "$RESTART_POLICY" "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker start "$CONTAINER_NAME" >/dev/null
    echo "Container '$CONTAINER_NAME' started."
    return 0
  fi

  echo "Starting container '$CONTAINER_NAME' from image '$IMAGE_NAME'..."
  local admin_args=()
  if [[ -n "${ADMIN_KEY:-}" ]]; then
    admin_args=(-e "Admin__AuthKey=${ADMIN_KEY}")
  fi

  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart "$RESTART_POLICY" \
    --user "$RUN_AS" \
    -e "HOME=/tmp" \
    -p "${HOST_PORT}:${CONTAINER_PORT}" \
    -e "ASPNETCORE_URLS=http://0.0.0.0:${CONTAINER_PORT}" \
    -e "ConnectionStrings__Board=Data Source=/data/collattice.db" \
    -e "Hosting__ServeSpa=true" \
    -e "Hosting__ListenAddress=0.0.0.0" \
    -e "Hosting__ListenPort=${CONTAINER_PORT}" \
    "${admin_args[@]}" \
    -v "${DATA_DIR}:/data" \
    "$IMAGE_NAME" >/dev/null

  echo "Container '$CONTAINER_NAME' is running on http://localhost:${HOST_PORT}"
}

stop_container() {
  if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
    echo "Disabling restart policy for '$CONTAINER_NAME'..."
    docker update --restart no "$CONTAINER_NAME" >/dev/null 2>&1 || true

    echo "Stopping container '$CONTAINER_NAME'..."
    docker stop "$CONTAINER_NAME" >/dev/null || true
    echo "Container '$CONTAINER_NAME' stopped."
  else
    echo "Container '$CONTAINER_NAME' is not running."
  fi
}

restart_container() {
  stop_container || true
  if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
    echo "Removing container '$CONTAINER_NAME' so it is recreated from '$IMAGE_NAME'..."
    docker rm "$CONTAINER_NAME" >/dev/null
  fi
  start_container
}

status_container() {
  if docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
    echo "Container '$CONTAINER_NAME' is running."
  elif docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
    echo "Container '$CONTAINER_NAME' exists but is stopped."
  else
    echo "Container '$CONTAINER_NAME' does not exist."
  fi
}

case "${1:-}" in
  start)
    start_container
    ;;
  stop)
    stop_container
    ;;
  restart)
    restart_container
    ;;
  status)
    status_container
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
