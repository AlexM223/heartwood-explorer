#!/usr/bin/env bash
#
# Heartwood dev image builder
# ---------------------------
# Reproduces the mempool CI Docker build (.github/workflows/docker.yml) locally,
# producing local `:dev` images you can run with the compose override in this
# directory.
#
# Prereqs: Docker Desktop with buildx, internet access (init.sh downloads GeoIP
# databases and the build pulls base images / crates).
#
# Usage:  heartwood/dev/build-images.sh [TAG]
#   TAG   optional build/version tag baked into the images (default: dev-local)
#
# Note: docker/init.sh mutates ./backend and ./frontend (copies Dockerfiles,
# nginx configs, downloads GeoIP DBs). Those paths are already .gitignore'd and
# are additionally listed in .git/info/exclude, so they never show up as git
# noise. This script only ADDS local images; it never modifies tracked files.

set -euo pipefail

# Resolve the repo root regardless of where the script is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

TAG="${1:-dev-local}"
SHORT_SHA="$(git rev-parse --short=8 HEAD 2>/dev/null || echo devlocal)"

FRONTEND_IMAGE="heartwood-frontend:dev"
BACKEND_IMAGE="heartwood-backend:dev"

echo "==> Repo root:      ${REPO_ROOT}"
echo "==> Build tag:      ${TAG}"
echo "==> Commit (short): ${SHORT_SHA}"

echo "==> Initialising Dockerization tree (docker/init.sh)"
# docker/init.sh downloads the GeoIP DBs with wget, which Git Bash on Windows
# does not ship. Those wget lines fail harmlessly (GeoIP is optional runtime
# data and the backend build COPYs the dir whether or not it has content); we
# backfill the DBs below with curl so local images match CI when possible.
docker/init.sh "${TAG}" || true

echo "==> Ensuring GeoIP databases (curl fallback for missing wget)"
GEOIP_DIR="./backend/GeoIP"
GEOIP_BASE="https://raw.githubusercontent.com/mempool/geoip-data/master"
mkdir -p "${GEOIP_DIR}"
for db in GeoLite2-City.mmdb GeoLite2-ASN.mmdb; do
  if [ ! -s "${GEOIP_DIR}/${db}" ]; then
    echo "    downloading ${db}"
    curl -fsSL -o "${GEOIP_DIR}/${db}" "${GEOIP_BASE}/${db}" \
      || echo "    WARNING: could not fetch ${db} (backend will run without GeoIP)"
  fi
done

echo "==> Building frontend image -> ${FRONTEND_IMAGE}"
docker buildx build \
  --tag "${FRONTEND_IMAGE}" \
  --build-arg commitHash="${SHORT_SHA}" \
  --load \
  --platform linux/amd64 \
  ./frontend/

echo "==> Building backend image -> ${BACKEND_IMAGE}"
docker buildx build \
  --tag "${BACKEND_IMAGE}" \
  --build-context rustgbt=./rust \
  --build-context backend=./backend \
  --build-arg commitHash="${SHORT_SHA}" \
  --load \
  --platform linux/amd64 \
  ./backend/

echo ""
echo "==> Done. Built images:"
echo "      ${FRONTEND_IMAGE}"
echo "      ${BACKEND_IMAGE}"
echo ""
echo "Bring the stack up with the compose override:"
echo "  docker compose -f docker/docker-compose.yml -f heartwood/dev/docker-compose.override.yml up"
