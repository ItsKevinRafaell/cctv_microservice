#!/usr/bin/env bash
set -euo pipefail

# Demo data seeder (multi-company) for Git Bash / Unix shells.
# - Login as superadmin
# - Provision several showcase companies, users, cameras, and sample anomalies
# - Optionally trigger push notifications for each company admin
# - Prints reset prompt for rebuilding Docker environment from scratch
#
# Environment overrides:
#   API_BASE=http://127.0.0.1:8080
#   SUPER_EMAIL=superadmin@example.com
#   SUPER_PASSWORD=ChangeMe123!
#   DEFAULT_USER_PASSWORD=SecurePass!2024
#   WORKER_SHARED_TOKEN=...      # if backend enforces X-Worker-Token
#   DOCKER_COMPOSE_CMD='docker compose'
#   SKIP_NOTIF=1                 # skip push notification smoke test

API_BASE="${API_BASE:-http://10.68.107.73:8080}"
SUPER_EMAIL="${SUPER_EMAIL:-superadmin@example.com}"
SUPER_PASSWORD="${SUPER_PASSWORD:-ChangeMe123!}"
DEFAULT_USER_PASSWORD="${DEFAULT_USER_PASSWORD:-SecurePass!2024}"
WORKER_SHARED_TOKEN="${WORKER_SHARED_TOKEN:-}"
DOCKER_COMPOSE_CMD="${DOCKER_COMPOSE_CMD:-docker compose}"
SKIP_NOTIF="${SKIP_NOTIF:-0}"

declare -A COMPANY_IDS
declare -A CAMERA_IDS
declare -A ADMIN_EMAIL
declare -A ADMIN_PASSWORD

code=""
body=""

log() { printf '%s\n' "$1"; }
info() { log "[seed] $1"; }
warn() { log "[seed][WARN] $1"; }
error_exit() { log "[seed][ERROR] $1"; exit 1; }

curl_json() {
  local method="$1"; shift
  local url="$1"; shift
  local data="${1:-}"; shift || true
  local args=("-sS" "-w" "\n%{http_code}" "-H" "Content-Type: application/json")
  while (($#)); do args+=("-H" "$1"); shift; done
  if [[ -n "$data" ]]; then
    args+=("-X" "$method" "-d" "$data" "$url")
  else
    args+=("-X" "$method" "$url")
  fi
  local out
  if ! out=$(curl "${args[@]}"); then
    error_exit "curl request failed: $method $url"
  fi
  code="${out##*$'\n'}"
  body="${out%$'\n'$code}"
}

extract_json_string() {
  local key="$1"; local json="$2"
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" <<<"$json"
}

extract_json_number() {
  local key="$1"; local json="$2"
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p" <<<"$json"
}

find_company_id_by_name() {
  local name="$1"; local json="$2"
  sed -n "s/.*\"id\"[[:space:]]*:[[:space:]]*\([0-9]\+\)[^}]*\"name\"[[:space:]]*:[[:space:]]*\"${name}\".*/\1/p" <<<"$json" | head -n1
}

find_camera_id_by_stream_key() {
  local stream_key="$1"; local json="$2"
  sed -n "s/.*\"id\"[[:space:]]*:[[:space:]]*\([0-9]\+\)[^}]*\"stream_key\"[[:space:]]*:[[:space:]]*\"${stream_key}\".*/\1/p" <<<"$json" | head -n1
}

wait_for_backend() {
  info "Waiting for $API_BASE/healthz ..."
  local tries=0
  until curl -fsS "$API_BASE/healthz" >/dev/null 2>&1; do
    tries=$((tries+1))
    if [[ "$tries" -gt 90 ]]; then
      error_exit "Backend not ready after 90s"
    fi
    sleep 1
  done
  info "Backend is reachable."
}

super_login() {
  info "Authenticating as superadmin ($SUPER_EMAIL)..."
  local login_body
  login_body=$(printf '{"email":"%s","password":"%s"}' "$SUPER_EMAIL" "$SUPER_PASSWORD")
  curl_json POST "$API_BASE/api/login" "$login_body"
  [[ "$code" == "200" ]] || error_exit "Superadmin login failed ($code): $body"
  SUPER_TOKEN=$(extract_json_string token "$body")
  [[ -n "$SUPER_TOKEN" ]] || error_exit "Missing token in superadmin login response"
  AUTH_H="Authorization: Bearer $SUPER_TOKEN"
  info "Superadmin login OK."
}

ensure_company() {
  local slug="$1"; local name="$2"; local description="$3"
  info "Ensuring company: $name"
  curl_json GET "$API_BASE/api/companies" "" "$AUTH_H"
  local company_id
  company_id=$(find_company_id_by_name "$name" "$body")
  if [[ -z "$company_id" ]]; then
    local payload
    payload=$(printf '{"name":"%s","notes":"%s"}' "$name" "$description")
    curl_json POST "$API_BASE/api/companies" "$payload" "$AUTH_H"
    if [[ "$code" =~ ^20 ]]; then
      company_id=$(extract_json_number company_id "$body")
    fi
    if [[ -z "$company_id" ]]; then
      curl_json GET "$API_BASE/api/companies" "" "$AUTH_H"
      company_id=$(find_company_id_by_name "$name" "$body")
    fi
    [[ -n "$company_id" ]] || error_exit "Failed to create or fetch company: $name"
    info "  -> created company_id=$company_id"
  else
    info "  -> reusing existing company_id=$company_id"
  fi
  COMPANY_IDS["$slug"]="$company_id"
}

ensure_user() {
  local slug="$1"; local role="$2"; local email="$3"; local password="$4"
  local company_id="${COMPANY_IDS[$slug]}"
  [[ -n "$company_id" ]] || error_exit "company_id missing for slug=$slug (user $email)"
  local payload
  payload=$(printf '{"email":"%s","password":"%s","company_id":%s,"role":"%s"}' "$email" "$password" "$company_id" "$role")
  curl_json POST "$API_BASE/api/register" "$payload" "$AUTH_H"
  if [[ "$code" == "201" ]]; then
    info "  -> user created: $email ($role)"
  elif [[ "$code" == "409" ]]; then
    info "  -> user already exists: $email"
  elif [[ "$code" =~ ^20 ]]; then
    info "  -> user ensured: $email"
  else
    error_exit "Failed to register user $email ($code): $body"
  fi
  if [[ "$role" == "company_admin" ]]; then
    ADMIN_EMAIL["$slug"]="$email"
    ADMIN_PASSWORD["$slug"]="$password"
  fi
}

ensure_camera() {
  local slug="$1"; local stream_key="$2"; local name="$3"; local location="$4"; local rtsp="$5"
  local company_id="${COMPANY_IDS[$slug]}"
  [[ -n "$company_id" ]] || error_exit "company_id missing for slug=$slug (camera $stream_key)"
  curl_json GET "$API_BASE/api/cameras?company_id=$company_id" "" "$AUTH_H"
  local cam_id
  cam_id=$(find_camera_id_by_stream_key "$stream_key" "$body")
  if [[ -z "$cam_id" ]]; then
    local payload
    payload=$(printf '{"name":"%s","location":"%s","stream_key":"%s","rtsp_source":"%s","company_id":%s}' \
      "$name" "$location" "$stream_key" "$rtsp" "$company_id")
    curl_json POST "$API_BASE/api/cameras" "$payload" "$AUTH_H"
    if [[ "$code" =~ ^20 ]]; then
      cam_id=$(extract_json_number camera_id "$body")
    fi
    if [[ -z "$cam_id" ]]; then
      curl_json GET "$API_BASE/api/cameras?company_id=$company_id" "" "$AUTH_H"
      cam_id=$(find_camera_id_by_stream_key "$stream_key" "$body")
    fi
    [[ -n "$cam_id" ]] || error_exit "Failed to provision camera $stream_key for $slug"
    info "  -> camera created: $stream_key (id=$cam_id)"
  else
    info "  -> camera exists: $stream_key (id=$cam_id)"
  fi
  CAMERA_IDS["$slug|$stream_key"]="$cam_id"
}

seed_anomaly() {
  local slug="$1"; local stream_key="$2"; local event_type="$3"; local clip_path="$4"; local confidence="$5"
  local cam_id="${CAMERA_IDS[$slug|$stream_key]}"
  if [[ -z "$cam_id" ]]; then
    warn "Skip anomaly seed for $stream_key (camera id not found)"
    return
  fi
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local clip_section=""
  if [[ -n "$clip_path" ]]; then
    clip_section=$(printf ',"video_clip_url":"%s"' "$clip_path")
  fi
  local payload
  payload=$(printf '{"camera_id":%s,"anomaly_type":"%s","confidence":%s,"reported_at":"%s"%s}' \
    "$cam_id" "$event_type" "$confidence" "$timestamp" "$clip_section")
  local headers=()
  [[ -n "$WORKER_SHARED_TOKEN" ]] && headers+=("X-Worker-Token: $WORKER_SHARED_TOKEN")
  curl_json POST "$API_BASE/api/report-anomaly" "$payload" "${headers[@]}"
  if [[ "$code" =~ ^20 ]]; then
    info "  -> anomaly recorded for $stream_key (type=$event_type, confidence=$confidence)"
  else
    warn "  -> anomaly seed failed for $stream_key ($code): $body"
  fi
}

login_as() {
  local email="$1"; local password="$2"
  local payload=$(printf '{"email":"%s","password":"%s"}' "$email" "$password")
  curl_json POST "$API_BASE/api/login" "$payload"
  [[ "$code" == "200" ]] || return 1
  local token
  token=$(extract_json_string token "$body")
  [[ -n "$token" ]] || return 1
  LOGIN_TOKEN="$token"
}

trigger_notification() {
  local slug="$1"
  local email="${ADMIN_EMAIL[$slug]}"
  local password="${ADMIN_PASSWORD[$slug]}"
  if [[ -z "$email" || -z "$password" ]]; then
    warn "Admin credentials missing for company $slug; skip notification test"
    return
  fi
  if ! login_as "$email" "$password"; then
    warn "Failed to login as $email for notification test"
    return
  fi
  local auth_header="Authorization: Bearer $LOGIN_TOKEN"
  curl_json POST "$API_BASE/api/notifications/test" '{}' "$auth_header"
  if [[ "$code" =~ ^20 ]]; then
    info "  -> push notification test queued for $email"
  else
    warn "  -> push notification test failed for $email ($code): $body"
  fi
}

print_reset_prompt() {
  cat <<'EOF'

[reset] To reset the Docker stack from scratch:
  docker compose down -v --remove-orphans
  docker volume prune -f
  docker compose build --no-cache
  docker compose up -d

Re-seed demo data afterwards with:
  bash scripts/seed_company3.sh
EOF
}

# --- Demo fixtures ---------------------------------------------------------

readarray -t COMPANY_FIXTURES <<'EOF'
acme|Acme Vision Inc|Security integrator specialising in mixed-use campuses
blueharbor|Blue Harbor Logistics|Logistics group monitoring maritime & warehouse assets
citra|Citra Retail Group|Retail conglomerate modernising loss prevention
EOF

readarray -t USER_FIXTURES <<EOF
acme|company_admin|ops.admin@acmevision.test|${DEFAULT_USER_PASSWORD}
acme|user|control.room@acmevision.test|${DEFAULT_USER_PASSWORD}
acme|user|regional.analyst@acmevision.test|${DEFAULT_USER_PASSWORD}
blueharbor|company_admin|command.center@blueharbor.test|${DEFAULT_USER_PASSWORD}
blueharbor|user|dock.supervisor@blueharbor.test|${DEFAULT_USER_PASSWORD}
blueharbor|user|maintenance.lead@blueharbor.test|${DEFAULT_USER_PASSWORD}
citra|company_admin|safety.admin@citraretail.test|${DEFAULT_USER_PASSWORD}
citra|user|store.manager@citraretail.test|${DEFAULT_USER_PASSWORD}
citra|user|risk.officer@citraretail.test|${DEFAULT_USER_PASSWORD}
EOF

readarray -t CAMERA_FIXTURES <<'EOF'
acme|cam-acme-hq-lobby|HQ Lobby Entrance|Jakarta HQ - Lobby|rtsp://mediamtx:8554/cam3
acme|cam-acme-dc-yard|Distribution Center Yard|Bekasi DC - Loading Yard|rtsp://mediamtx:8554/cam3
blueharbor|cam-bhl-dock01|Dock 01 Loading Bay|Tanjung Priok Hub - Dock 01|rtsp://mediamtx:8554/cam3
blueharbor|cam-bhl-coldstorage|Cold Storage Aisle|Warehouse Block C - Cold Storage|rtsp://mediamtx:8554/cam3
citra|cam-citra-flagship|Flagship Atrium Overview|Jakarta Flagship - Atrium|rtsp://mediamtx:8554/cam3
citra|cam-citra-parking|Parking Deck Barrier|Mall Central - Parking Deck P2|rtsp://mediamtx:8554/cam3
EOF

readarray -t ANOMALY_FIXTURES <<'EOF'
acme|cam-acme-hq-lobby|intrusion|/video-clips/cam3/demo_cam3.mp4|0.92
blueharbor|cam-bhl-dock01|trespassing|/video-clips/cam3/demo_cam3.mp4|0.88
citra|cam-citra-flagship|loitering|/video-clips/cam3/demo_cam3.mp4|0.90
EOF

# --- Execution -------------------------------------------------------------

info "API_BASE=$API_BASE"
wait_for_backend
super_login

for entry in "${COMPANY_FIXTURES[@]}"; do
  IFS='|' read -r slug name description <<<"$entry"
  ensure_company "$slug" "$name" "$description"
done

for entry in "${USER_FIXTURES[@]}"; do
  IFS='|' read -r slug role email password <<<"$entry"
  ensure_user "$slug" "$role" "$email" "$password"
done

for entry in "${CAMERA_FIXTURES[@]}"; do
  IFS='|' read -r slug stream_key name location rtsp <<<"$entry"
  ensure_camera "$slug" "$stream_key" "$name" "$location" "$rtsp"
done

for entry in "${ANOMALY_FIXTURES[@]}"; do
  IFS='|' read -r slug stream_key event_type clip_path confidence <<<"$entry"
  seed_anomaly "$slug" "$stream_key" "$event_type" "$clip_path" "$confidence"
done

if [[ "$SKIP_NOTIF" != "1" ]]; then
  for entry in "${COMPANY_FIXTURES[@]}"; do
    IFS='|' read -r slug _rest <<<"$entry"
    trigger_notification "$slug"
  done
else
  info "Skipping push notification smoke tests (SKIP_NOTIF=1)."
fi

cat <<EOF

[seed] Completed demo provisioning.

Accounts (password=${DEFAULT_USER_PASSWORD}):
  - Acme Vision Admin     : ${ADMIN_EMAIL[acme]}
  - Blue Harbor Admin     : ${ADMIN_EMAIL[blueharbor]}
  - Citra Retail Admin    : ${ADMIN_EMAIL[citra]}

Stream keys (semua diarahkan ke RTSP cam3):
  - Acme Vision           : cam-acme-hq-lobby, cam-acme-dc-yard
  - Blue Harbor Logistics : cam-bhl-dock01, cam-bhl-coldstorage
  - Citra Retail Group    : cam-citra-flagship, cam-citra-parking

Upload demo clip opsional:
  bucket video-clips/
    cam3/demo_cam3.mp4

EOF

print_reset_prompt
