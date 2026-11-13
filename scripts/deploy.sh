#!/usr/bin/env bash
# Usage: deploy.sh <image>
# Pulls the image, starts it, runs a smoke test on /health.
# If the smoke test fails, it rolls back to the previous image.
set -euo pipefail

NEW_IMAGE="${1:?usage: deploy.sh <image>}"
NAME="${NAME:-app}"
HOST_PORT="${HOST_PORT:-8080}"

# Extra docker run options (the EC2 bootstrap puts the CloudWatch log driver here)
EXTRA=()
if [[ -f /opt/app/extra_args ]]; then read -r -a EXTRA < /opt/app/extra_args || true; fi

run_container() {
  docker run -d --name "$NAME" -p "${HOST_PORT}:3000" --restart unless-stopped "${EXTRA[@]}" "$1" >/dev/null
}

healthy() {
  for _ in $(seq 1 15); do
    if curl -fsS "http://localhost:${HOST_PORT}/health" >/dev/null 2>&1; then return 0; fi
    sleep 2
  done
  return 1
}

PREV_IMAGE="$(docker inspect --format '{{.Config.Image}}' "$NAME" 2>/dev/null || true)"

docker pull "$NEW_IMAGE"
docker rm -f "$NAME" >/dev/null 2>&1 || true
run_container "$NEW_IMAGE"

if healthy; then
  echo "Deploy OK: $NEW_IMAGE"
  exit 0
fi

echo "Smoke test FAILED for $NEW_IMAGE" >&2
docker rm -f "$NAME" >/dev/null 2>&1 || true
if [[ -n "$PREV_IMAGE" ]]; then
  run_container "$PREV_IMAGE"
  echo "Rolled back to $PREV_IMAGE" >&2
else
  echo "No previous image to roll back to" >&2
fi
exit 1
