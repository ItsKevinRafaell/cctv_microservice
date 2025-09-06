#!/usr/bin/env python3
import os, sys, time, json, random, string
import requests

API_MAIN = os.getenv('API_MAIN_URL', 'http://localhost:8080')
API_INGEST = os.getenv('API_INGEST_URL', 'http://localhost:8081')

def rand_email():
    suffix = ''.join(random.choices(string.ascii_lowercase+string.digits, k=6))
    return f"tester_{suffix}@example.com"

def _print(step, ok, detail=""):
    status = "OK" if ok else "FAIL"
    print(f"[ {status:4} ] {step} {detail}")

def main():
    # 1) Create company
    company_name = f"Acme {random.randint(1000,9999)}"
    r = requests.post(f"{API_MAIN}/api/companies", json={"name": company_name, "address": "-"})
    ok = r.status_code in (200,201)
    _print("Create company", ok, f"status={r.status_code}")
    if not ok:
        print(r.text); sys.exit(1)
    company_id = r.json().get('company_id') if r.headers.get('content-type','').startswith('application/json') else None
    if not company_id:
        # fallback: list and take last
        rr = requests.get(f"{API_MAIN}/api/companies")
        company_id = rr.json()[-1]['id'] if rr.ok and isinstance(rr.json(), list) else 1

    # 2) Register user
    email = rand_email(); password = "secret123"
    r = requests.post(f"{API_MAIN}/api/register", json={"email": email, "password": password, "company_id": company_id, "role": "company_admin"})
    _print("Register user", r.status_code == 201, f"status={r.status_code}")

    # 3) Login
    r = requests.post(f"{API_MAIN}/api/login", json={"email": email, "password": password})
    if not r.ok:
        _print("Login", False, f"status={r.status_code} {r.text}"); sys.exit(1)
    token = r.json()['token']
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    _print("Login", True)

    # 4) Create camera (set stream_key agar konsisten dgn Mediamtx/archiver)
    r = requests.post(
        f"{API_MAIN}/api/cameras",
        headers=headers,
        json={"name": "Lobby", "location": "L1", "stream_key": "cam1"}
    )
    ok = r.status_code in (200,201)
    _print("Create camera", ok, f"status={r.status_code}")
    if not ok: print(r.text); sys.exit(1)
    camera_id = r.json().get('camera_id', 0)

    # 5) List cameras
    r = requests.get(f"{API_MAIN}/api/cameras", headers=headers)
    _print("List cameras", r.ok, f"count={len(r.json()) if r.ok else '?'}")

    # 6) Update camera
    r = requests.put(f"{API_MAIN}/api/cameras/{camera_id}", headers=headers, json={"name": "Lobby-Updated"})
    _print("Update camera", r.ok, f"status={r.status_code}")

    # 7) Update FCM token
    fcm_token = os.getenv('FCM_TOKEN', '').strip()
    if not fcm_token:
        # fallback: read from token.txt at repo root
        try:
            with open(os.path.join(os.getcwd(), 'token.txt'), 'r', encoding='utf-8') as f:
                fcm_token = f.read().strip()
        except Exception:
            fcm_token = ''
    if fcm_token:
        r = requests.post(f"{API_MAIN}/api/users/fcm-token", headers=headers, json={"fcm_token": fcm_token})
        _print("Update FCM token", r.ok, f"status={r.status_code}")
    else:
        _print("Update FCM token", False, "no token provided (env FCM_TOKEN or token.txt)")

    # 8) List users
    r = requests.get(f"{API_MAIN}/api/users", headers=headers)
    _print("List users", r.ok, f"count={len(r.json()) if r.ok else '?'}")

    # 9) Report anomaly (simulate AI)
    payload = {"camera_id": camera_id, "anomaly_type": "model_detected", "confidence": 0.72, "video_clip_url": "http://example/clip.mp4"}
    r = requests.post(f"{API_MAIN}/api/report-anomaly", json=payload)
    _print("Report anomaly", r.ok, f"status={r.status_code}")

    # 10) Get recent anomalies + fetch detail for newest
    r = requests.get(f"{API_MAIN}/api/anomalies/recent?limit=10", headers=headers)
    _print("List recent anomalies", r.ok, f"count={len(r.json()) if r.ok else '?'}")
    if r.ok and isinstance(r.json(), list) and r.json():
        anom_id = r.json()[0].get('id')
        if anom_id:
            rd = requests.get(f"{API_MAIN}/api/anomalies/{anom_id}", headers=headers)
            _print("Anomaly detail", rd.ok, f"status={rd.status_code}")

    # 11) List recordings (likely empty in fresh env)
    r = requests.get(f"{API_MAIN}/api/cameras/{camera_id}/recordings?presign=0", headers=headers)
    ok = r.ok
    cnt = r.json().get('count', 0) if ok else '?'
    _print("List recordings", ok, f"count={cnt}")

    # 12) Ingest service health
    try:
        r = requests.get(f"{API_INGEST}/healthz", timeout=2)
        _print("Ingestion health", r.ok)
    except Exception as e:
        _print("Ingestion health", False, str(e))

    print("\nAll checks done. If FCM token was set, a push should arrive.")

if __name__ == '__main__':
    main()
