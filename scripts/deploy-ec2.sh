#!/usr/bin/env bash
set -eu

# --- 1. Authenticate EC2's Docker client to ECR using the instance role ---
TOKEN="$(aws ecr get-login-password --region "@REGION@")"
printf '%s' "$TOKEN" | docker login --username AWS --password-stdin "@REGISTRY@"

IMAGE="@REGISTRY@/@REPOSITORY@:@IMAGE_TAG@"

# --- 2. Pull the new image BEFORE stopping the old container ---
docker pull "$IMAGE"

# --- 3. Replace the container (idempotent: nothing to stop on first deploy) ---
docker stop myappcontainer 2>/dev/null || true
docker rm myappcontainer 2>/dev/null || true

docker run -d \
  --name myappcontainer \
  --restart unless-stopped \
  -p 80:8080 \
  "$IMAGE"

# --- 4. Health check: the application must answer on host port 80 ---
for attempt in 1 2 3 4 5; do
  if curl --fail --silent http://localhost/ >/dev/null; then
    echo "Health check passed (attempt $attempt)"
    exit 0
  fi
  sleep 2
done

echo "Health check failed after 5 attempts"
docker logs myappcontainer
exit 1