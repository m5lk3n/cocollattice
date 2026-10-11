# cocollattice

Containerized [Collattice](https://github.com/MrBildo/collattice).

## Overview

This repository includes helper scripts for:

- downloading the latest Collattice Linux release
- extracting the published binary
- building a Docker image
- starting, stopping, and checking the container
- showing the admin key from container logs
- resetting the database to recreate first-run state

## Build the Docker image

From the [latest Collattice release page](https://github.com/MrBildo/collattice/releases), the helper script downloads the Linux tarball matching the target architecture, verifies the checksum when available, extracts the files, and builds a Docker image.

```bash
# Default architecture is x64
./build-collattice-image.sh

# Optional: build for arm64
TARGET_ARCH=arm64 ./build-collattice-image.sh

# Optional: customize the image tag
IMAGE_NAME=my-collattice:latest ./build-collattice-image.sh
```

The script stores the downloaded archive and extracted runtime under a temporary build directory (cleared on every run), then builds an image tagged with the value of `IMAGE_NAME`. Set `GITHUB_TOKEN` to avoid GitHub API rate limits.

The image sets a default admin key of `cocollattice` (`Admin__AuthKey`). Override it at runtime with `ADMIN_KEY=... ./collattice-container.sh restart`, or `docker run -e Admin__AuthKey=...`.

After rebuilding, run `./collattice-container.sh restart` so the container is recreated from the new image.

## Start and stop the container

```bash
# Start the container
./collattice-container.sh start

# Stop it
./collattice-container.sh stop

# Restart it
./collattice-container.sh restart

# Check status
./collattice-container.sh status
```

Environment variables supported by the container script:

- `IMAGE_NAME` — Docker image tag (default: `collattice:latest`)
- `CONTAINER_NAME` — container name (default: `collattice`)
- `HOST_PORT` — host port mapping (default: `8080`)
- `CONTAINER_PORT` — container port (default: `8080`)
- `DATA_DIR` — host directory for the SQLite database (default: `./collattice`)
- `RESTART_POLICY` — Docker restart policy (default: `unless-stopped`; set to `no` to disable auto-restart)
- `RUN_AS` — `uid:gid` the container runs as (default: your own, from `id -u`/`id -g`, so files in `DATA_DIR` belong to you rather than root)
- `ADMIN_KEY` — admin auth key passed to the container (default: the image's `cocollattice`)

The user is fixed when the container is created, so run `restart` once to switch an existing container (and `chown` any root-owned files in `DATA_DIR` first). `restart` removes and recreates the container (data in `DATA_DIR` is kept). `start` on an existing container reapplies `RESTART_POLICY`.

The container script disables Docker auto-restart before calling `docker stop`, so a stopped container stays stopped instead of immediately restarting.

Example:

```bash
RESTART_POLICY=no IMAGE_NAME=collattice:dev HOST_PORT=9090 CONTAINER_NAME=collattice-dev ./collattice-container.sh start
```

## Show the admin key

```bash
./show-admin-key.sh
```

This reads the Collattice container logs and prints the admin auth key. If the key was set explicitly (the image default or `ADMIN_KEY`), the app may not log it; the default is `cocollattice`.

## Reset to first-run state

```bash
./reset-collattice.sh --reset-db        # asks for confirmation
./reset-collattice.sh --reset-db --yes  # no prompt
```

This stops the container, removes the SQLite database (including `-wal`/`-shm` files), and starts it again so Collattice recreates its initial admin and default board setup.

---

## Bookmarks

- [Collattice Releases](https://github.com/MrBildo/collattice/releases/latest)
