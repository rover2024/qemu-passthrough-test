#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-ubuntu:22.04}"
CONTAINER_NAME="${2:-passthrough-container}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

docker run --rm -it \
  --name "$CONTAINER_NAME" \
  -v "$SCRIPT_DIR:/home/user/docker" \
  -w /home/user/docker \
  "$IMAGE" bash
