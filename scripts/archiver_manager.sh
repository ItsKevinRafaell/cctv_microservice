#!/bin/sh
set -eu

# CAMERA_LIST format: cam1=rtsp://... ,cam2=rtsp://... (comma-separated)
# SEGMENT_SECONDS: default 3600

CAMERA_LIST=${CAMERA_LIST:-}
SEGMENT_SECONDS=${SEGMENT_SECONDS:-3600}

if [ -z "$CAMERA_LIST" ]; then
  echo "No CAMERA_LIST provided. Example: cam1=rtsp://mediamtx:8554/cam1,cam2=rtsp://mediamtx:8554/cam2"
  sleep 3600
  exit 0
fi

echo "Launching archivers for: $CAMERA_LIST with segment=$SEGMENT_SECONDS sec"

IFS=','
for pair in $CAMERA_LIST; do
  name=${pair%%=*}
  url=${pair#*=}
  if [ -z "$name" ] || [ -z "$url" ]; then
    echo "Skip invalid entry: $pair"
    continue
  fi
  out="/recordings/${name}_%Y%m%d_%H%M%S.mp4"
  echo "Start FFmpeg for $name -> $out"
  (
    exec ffmpeg -hide_banner -loglevel info -rtsp_transport tcp -i "$url" \
      -c copy -f segment -segment_time "$SEGMENT_SECONDS" -reset_timestamps 1 -strftime 1 "$out"
  ) &
done

wait

