# CCTV Microservice API (Frontend Guide)

This backend exposes REST endpoints for auth, companies, cameras, anomalies, recordings and the ingestion service.

- Full spec: `docs/openapi.yaml` (OpenAPI 3.0)
- Base URLs:
  - Main Backend: `http://localhost:8080`
  - Ingestion Service: `http://localhost:8081`

## Quick Reference

Auth
- POST `/api/register` — body `{ email, password, company_id, role? }`
- POST `/api/login` — body `{ email, password }` -> `{ token }`
- Auth header: `Authorization: Bearer <token>`

Companies
- POST `/api/companies` — `{ name, address }`
- GET `/api/companies`
- PUT `/api/companies/{id}` — `{ name?, address? }`
- DELETE `/api/companies/{id}`

Cameras (JWT required)
- POST `/api/cameras` — `{ name, location? }` 
- GET `/api/cameras`
- PUT `/api/cameras/{id}` — `{ name?, location? }`
- DELETE `/api/cameras/{id}`
- GET `/api/cameras/{id}/recordings?from=<RFC3339>&to=<RFC3339>&presign=0|1`

Anomalies
- POST `/api/report-anomaly` — `{ camera_id, anomaly_type?, confidence?, video_clip_url? }`
- GET `/api/anomalies` (JWT)
- GET `/api/anomalies/recent?limit=20` (JWT)

Ingestion Service
- POST `/ingest/video` (multipart): fields `video_clip` (file), `camera_id` (string)

## cURL Examples

1) Register + Login
```
curl -sS -X POST http://localhost:8080/api/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com","password":"secret","company_id":1,"role":"company_admin"}'

curl -sS -X POST http://localhost:8080/api/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com","password":"secret"}'
```

2) Create camera
```
TOKEN=... # from login
curl -sS -X POST http://localhost:8080/api/cameras \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"name":"Lobby","location":"L1"}'
```

3) List recordings with presigned URLs
```
curl -sS -H "Authorization: Bearer $TOKEN" \
  'http://localhost:8080/api/cameras/1/recordings?presign=1'
```

4) Upload short clip to ingestion
```
curl -sS -X POST http://localhost:8081/ingest/video \
  -F camera_id=1 -F video_clip=@./sample.mp4
```

## Automation Smoke Test

Script: `scripts/smoke_test_api.py`

What it does:
- Create a company
- Register user and login (JWT)
- Create camera, list cameras
- Update FCM token
- Submit anomaly (simulates AI worker)
- Read recent anomalies
- List recordings
- Check ingestion health endpoint

Run:
```
API_MAIN_URL=http://localhost:8080 \
API_INGEST_URL=http://localhost:8081 \
python3 scripts/smoke_test_api.py
```

Notes:
- Run after `docker-compose up` so all services are available.
- The script generates random email to avoid conflicts.

