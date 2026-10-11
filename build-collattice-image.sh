#!/usr/bin/env bash
set -Eeuo pipefail

REPO="MrBildo/collattice"
TARGET_ARCH="${TARGET_ARCH:-x64}"
IMAGE_NAME="${IMAGE_NAME:-collattice:latest}"
WORKDIR="${WORKDIR:-$(pwd)/.collattice-build}"

case "$TARGET_ARCH" in
  x64|arm64) ;;
  *)
    echo "Unsupported TARGET_ARCH: ${TARGET_ARCH}. Use x64 or arm64." >&2
    exit 1
    ;;
esac

mkdir -p "$WORKDIR"
DL_DIR="${WORKDIR}/tmp"
EXTRACT_DIR="${WORKDIR}/extracted"
BUILD_DIR="${WORKDIR}/docker-context"

# Start from clean extract/context dirs so files from an older release can't leak into the image.
rm -rf "$EXTRACT_DIR" "$BUILD_DIR" "$DL_DIR"
mkdir -p "$DL_DIR" "$EXTRACT_DIR" "$BUILD_DIR"

echo "Fetching latest release metadata for ${REPO}..."
RELEASE_JSON="$(mktemp)"
trap 'rm -f "$RELEASE_JSON"' EXIT
CURL_AUTH=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  CURL_AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi
curl -fsSL "${CURL_AUTH[@]}" "https://api.github.com/repos/${REPO}/releases/latest" -o "$RELEASE_JSON"
TAG_NAME="$(jq -r '.tag_name' "$RELEASE_JSON")"

ASSET_NAME="$(jq -r --arg arch "$TARGET_ARCH" '.assets[].name | select(test("collattice-linux-" + $arch + "\\.tar\\.gz$"))' "$RELEASE_JSON" | head -n 1)"

if [[ -z "$ASSET_NAME" ]]; then
  echo "No Linux ${TARGET_ARCH} tar.gz asset found in release ${TAG_NAME}." >&2
  exit 1
fi

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG_NAME}/${ASSET_NAME}"
CHECKSUM_URL="${DOWNLOAD_URL}.sha256"

echo "Downloading ${ASSET_NAME}..."
curl -fsSL "$DOWNLOAD_URL" -o "${DL_DIR}/${ASSET_NAME}"

if curl -fsSL "$CHECKSUM_URL" -o "${DL_DIR}/${ASSET_NAME}.sha256"; then
  echo "Verifying checksum..."
  (cd "$DL_DIR" && sha256sum -c "${ASSET_NAME}.sha256")
else
  echo "No checksum file published for ${ASSET_NAME}; skipping verification."
fi

echo "Extracting release archive..."
tar -xzf "${DL_DIR}/${ASSET_NAME}" -C "$EXTRACT_DIR"

cp -a "${EXTRACT_DIR}/." "$BUILD_DIR/"

cat > "${BUILD_DIR}/Dockerfile" <<'EOF'
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends libicu72 libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

ENV ASPNETCORE_URLS=http://0.0.0.0:8080
ENV Admin__AuthKey=cocollattice
EXPOSE 8080

ENTRYPOINT ["./Collabot.Collattice.Api"]
EOF

echo "Building Docker image: ${IMAGE_NAME}"
docker build -t "$IMAGE_NAME" "$BUILD_DIR"

echo

echo "Done."
echo "Run with: ./collattice-container.sh restart   # recreates the container from the new image"
echo "Or:       docker run --rm -p 8080:8080 ${IMAGE_NAME}"
