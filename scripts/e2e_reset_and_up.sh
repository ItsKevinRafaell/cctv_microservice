#!/usr/bin/env bash
set -euo pipefail

echo "[e2e] Resetting Docker stack (down -v)" >&2
docker compose down -v || true

echo "[e2e] Building images" >&2
docker compose build

echo "[e2e] Starting core services" >&2
docker compose up -d db minio rabbitmq mediamtx push-service api_main archiver_manager recording_indexer

echo "[e2e] Waiting for backend to be ready..." >&2
tries=0
until curl -fsS http://127.0.0.1:8080/healthz >/dev/null 2>&1; do
  tries=$((tries+1))
  if [ "$tries" -gt 60 ]; then
    echo "Backend health check failed after 60s" >&2
    exit 1
  fi
  sleep 1
done

echo "[e2e] Health report:" >&2
curl -fsS http://127.0.0.1:8080/api/health/report || true
echo

echo "[e2e] Done. Next: ./scripts/seed_company3.sh and start app." >&2
