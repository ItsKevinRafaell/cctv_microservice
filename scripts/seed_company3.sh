#!/usr/bin/env bash
set -euo pipefail

# Simple seeder for Git Bash / Unix shells
# - Logs in as superadmin
# - Creates company admin (company_id=3 by default)
# - Creates a camera with given stream_key
# - Sends an anomaly (optional clip path for presign)
# - Optionally upserts an FCM token for the new user (to test push)

API_BASE="${API_BASE:-http://127.0.0.1:8080}"
COMPANY_ID="${COMPANY_ID:-3}"
COMPANY_NAME="${COMPANY_NAME:-Company 3}"
SUPER_EMAIL="${SUPER_EMAIL:-superadmin@example.com}"
SUPER_PASSWORD="${SUPER_PASSWORD:-ChangeMe123!}"
NEW_USER_EMAIL="${NEW_USER_EMAIL:-company3admin@example.com}"
NEW_USER_PASSWORD="${NEW_USER_PASSWORD:-Passw0rd123!}"
STREAM_KEY="${STREAM_KEY:-cam3}"
# For presign, use path-like: /video-clips/cam3/clip_001.mp4
CLIP_PATH="${CLIP_PATH:-/video-clips/cam3/clip_001.mp4}"
# If your backend enforces a shared worker token for /api/report-anomaly
WORKER_SHARED_TOKEN="${WORKER_SHARED_TOKEN:-}"
# Optional: provide an app FCM token to register on backend
FCM_TOKEN="${FCM_TOKEN:-}"

echo "[seed] API_BASE=$API_BASE COMPANY_ID=$COMPANY_ID STREAM_KEY=$STREAM_KEY"

code=""
body=""

curl_json() {
  local method="$1"; shift
  local url="$1"; shift
  local data="${1:-}"; shift || true
  local args=("-sS" "-w" "\n%{http_code}" "-H" "Content-Type: application/json")
  # Remaining args are headers: "-H" "Header: value" ...
  while (($#)); do args+=("-H" "$1"); shift; done
  if [[ -n "$data" ]]; then args+=("-X" "$method" "-d" "$data" "$url"); else args+=("-X" "$method" "$url"); fi
  local out
  if ! out=$(curl "${args[@]}"); then
    echo "[curl] request failed: $method $url" >&2; exit 1
  fi
  code="${out##*$'\n'}"; body="${out%$'\n'$code}"
}

extract_json_string() { # key, json -> prints value or empty
  local key="$1"; local json="$2"
  # naive extractor sufficient for our predictable shapes
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" <<<"$json"
}

extract_json_number() { # key, json -> prints value or empty
  local key="$1"; local json="$2"
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p" <<<"$json"
}

# 0) Wait for backend health
echo "[seed] Waiting for $API_BASE/healthz ..."
tries=0
until curl -fsS "$API_BASE/healthz" >/dev/null 2>&1; do
  tries=$((tries+1))
  if [[ "$tries" -gt 60 ]]; then echo "[seed] backend not ready after 60s" >&2; exit 1; fi
  sleep 1
done

# 1) Login as superadmin
echo "[seed] Login as superadmin ${SUPER_EMAIL}..."
login_body=$(printf '{"email":"%s","password":"%s"}' "$SUPER_EMAIL" "$SUPER_PASSWORD")
curl_json POST "$API_BASE/api/login" "$login_body"
if [[ "$code" != 200 ]]; then echo "[seed] login failed ($code): $body"; exit 1; fi
SUPER_TOKEN=$(extract_json_string token "$body")
[[ -z "$SUPER_TOKEN" ]] && { echo "[seed] missing token in login response"; exit 1; }
AUTH_H="Authorization: Bearer $SUPER_TOKEN"
echo "[seed] OK"

# 2) Ensure company exists (resolve or create)
echo "[seed] Resolve company id..."
curl_json GET "$API_BASE/api/companies" "" "$AUTH_H"
resolved_id=$(sed -n "s/.*\"id\"[[:space:]]*:[[:space:]]*\([0-9]\+\)[^}]*\"name\"[[:space:]]*:[[:space:]]*\"${COMPANY_NAME//\//\/}\".*/\1/p" <<<"$body" | head -n1)
if [[ -z "$resolved_id" ]]; then
  # Try match by requested id if present in list
  resolved_id=$(sed -n "s/.*\"id\"[[:space:]]*:[[:space:]]*\(${COMPANY_ID}\)\b.*/\1/p" <<<"$body" | head -n1)
fi
if [[ -z "$resolved_id" ]]; then
  echo "[seed] Create company: $COMPANY_NAME"
  curl_json POST "$API_BASE/api/companies" "$(printf '{"name":"%s"}' "$COMPANY_NAME")" "$AUTH_H"
  resolved_id=$(sed -n "s/.*\"company_id\"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p" <<<"$body")
fi
if [[ -z "$resolved_id" ]]; then echo "[seed] Failed to resolve company id" >&2; exit 1; fi
COMPANY_ID="$resolved_id"
echo "[seed] Company id=$COMPANY_ID"

# 3) Ensure company admin user exists
echo "[seed] Ensure user $NEW_USER_EMAIL in company $COMPANY_ID..."
register_body=$(printf '{"email":"%s","password":"%s","company_id":%s,"role":"company_admin"}' "$NEW_USER_EMAIL" "$NEW_USER_PASSWORD" "$COMPANY_ID")
curl_json POST "$API_BASE/api/register" "$register_body" "$AUTH_H"
if [[ "$code" =~ ^2 ]]; then echo "[seed] user created"; else echo "[seed] register non-2xx (likely exists): $code"; fi

# 3b) Optional: login as that user to upsert FCM token later
USER_TOKEN=""
user_login_body=$(printf '{"email":"%s","password":"%s"}' "$NEW_USER_EMAIL" "$NEW_USER_PASSWORD")
curl_json POST "$API_BASE/api/login" "$user_login_body"
if [[ "$code" == 200 ]]; then USER_TOKEN=$(extract_json_string token "$body"); fi

if [[ -n "$FCM_TOKEN" && -n "$USER_TOKEN" ]]; then
  echo "[seed] Upsert FCM token for $NEW_USER_EMAIL"
  curl_json POST "$API_BASE/api/users/fcm-token" "$(printf '{"fcm_token":"%s"}' "$FCM_TOKEN")" "Authorization: Bearer $USER_TOKEN"
  echo "[seed] FCM upsert status: $code"
fi

# 4) Create camera in company
echo "[seed] Create camera stream_key=$STREAM_KEY for company=$COMPANY_ID..."
create_cam_body=$(printf '{"name":"%s","location":"%s","stream_key":"%s","company_id":%s}' "Demo Cam $STREAM_KEY" "Demo" "$STREAM_KEY" "$COMPANY_ID")
curl_json POST "$API_BASE/api/cameras" "$create_cam_body" "$AUTH_H"
CAM_ID=$(extract_json_number camera_id "$body")
if [[ -z "$CAM_ID" ]]; then
  echo "[seed] Create returned $code; try resolving camera id from list..."
  curl_json GET "$API_BASE/api/cameras?company_id=$COMPANY_ID" "" "$AUTH_H"
  # Try: id before stream_key
  CAM_ID=$(sed -n "s/.*\"id\"[[:space:]]*:[[:space:]]*\([0-9]\+\)[^}]*\"stream_key\"[[:space:]]*:[[:space:]]*\"${STREAM_KEY}\".*/\1/p" <<<"$body")
  if [[ -z "$CAM_ID" ]]; then
    # Try: stream_key before id
    CAM_ID=$(sed -n "s/.*\"stream_key\"[[:space:]]*:[[:space:]]*\"${STREAM_KEY}\"[^}]*\"id\"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p" <<<"$body")
  fi
fi
[[ -z "$CAM_ID" ]] && { echo "[seed] Failed to obtain camera id"; exit 1; }
echo "[seed] Camera id=$CAM_ID"

# 5) Report anomaly
echo "[seed] Report anomaly for camera_id=$CAM_ID ..."
anom_body=$(printf '{"camera_id":%s,"anomaly_type":"%s","confidence":%s,"reported_at":"%s"%s}' \
  "$CAM_ID" "intrusion" "0.9" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "$( [[ -n "$CLIP_PATH" ]] && printf ',"video_clip_url":"%s"' "$CLIP_PATH" || printf '' )" )
extra_header=()
[[ -n "$WORKER_SHARED_TOKEN" ]] && extra_header+=("X-Worker-Token: $WORKER_SHARED_TOKEN")
curl_json POST "$API_BASE/api/report-anomaly" "$anom_body" "${extra_header[@]}"
echo "[seed] anomaly status: $code"

echo
echo "Next steps:"
echo "  1) Login on the app as: $NEW_USER_EMAIL / $NEW_USER_PASSWORD"
echo "  2) Home → Recent Alerts should show the anomaly; open detail to play clip if $CLIP_PATH exists in MinIO."
echo "  3) To start a dummy live stream to $STREAM_KEY:"
echo "     docker compose exec -d ffmpeg_rtsp_cam1 sh -lc 'ffmpeg -re -f lavfi -i testsrc=size=640x360:rate=25 -f lavfi -i sine=frequency=1000:sample_rate=48000 -c:v libx264 -preset veryfast -tune zerolatency -pix_fmt yuv420p -profile:v main -g 50 -c:a aac -b:a 128k -f rtsp -rtsp_transport tcp rtsp://mediamtx:8554/$STREAM_KEY'"
echo "  4) Watch push logs: docker compose logs -f push-service"
