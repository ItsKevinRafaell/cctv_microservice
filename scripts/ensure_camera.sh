#!/usr/bin/env bash
set -euo pipefail

: "${CAMERA_ID:=2}"
: "${COMPANY_ID:=2}"
: "${CAMERA_NAME:=Remote Camera ${CAMERA_ID}}"
: "${STREAM_KEY:=cam${CAMERA_ID}}"
: "${DOCKER_COMPOSE_CMD:=docker compose}"

echo "[ensure_camera] upserting camera_id=${CAMERA_ID} (company=${COMPANY_ID}, stream_key=${STREAM_KEY})"

SQL=$(cat <<EOF
INSERT INTO cameras (id, company_id, name, stream_key, created_at, updated_at)
VALUES (${CAMERA_ID}, ${COMPANY_ID}, '${CAMERA_NAME//\'/\'\'}', '${STREAM_KEY//\'/\'\'}', NOW(), NOW())
ON CONFLICT (id) DO UPDATE
  SET company_id = EXCLUDED.company_id,
      name       = EXCLUDED.name,
      stream_key = EXCLUDED.stream_key,
      updated_at = NOW();
EOF
)

${DOCKER_COMPOSE_CMD} exec -T db psql -U admin -d cctv_db -v "ON_ERROR_STOP=1" -c "${SQL}"

echo "[ensure_camera] done."
