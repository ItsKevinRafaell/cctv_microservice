# AnomEye (Flutter)

Clean, modular Flutter scaffold aligned with a CCTV anomaly detection prototype.

## Quick start
```bash
flutter pub get
# Default: uses localhost; on Android Emulator use 10.0.2.2
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=HLS_BASE_URL=http://10.0.2.2:8888

# Use fakes (no backend) if needed
# flutter run --dart-define=USE_FAKE=true
```
