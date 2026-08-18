#!/bin/bash
# OPNDRM VM guest screen recorder using FFmpeg.
# Captures the primary display and saves to the recording directory.
# Usage: ff-record.sh <recording-dir> <name> [--audio]

set -euo pipefail

DIR="$1"
NAME="$2"
AUDIO="${3:-}"

mkdir -p "$DIR/$NAME"

# Find the avfoundation screen device
SCREEN_DEVICE=$(ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep "capture" | head -1 | sed 's/.*\[\([0-9]*\).*\[.*/\1/' || echo "1")

OUTPUT="$DIR/$NAME/recording.mp4"
DB="$DIR/$NAME/recording.db"
VIEWER="$DIR/$NAME/viewer.html"

FFMPEG_ARGS=(
  -f avfoundation
  -framerate 30
  -capture_cursor 1
  -i "$SCREEN_DEVICE"
  -c:v h264_videotoolbox
  -preset medium
  -pix_fmt yuv420p
  "$OUTPUT"
)

if [[ "$AUDIO" == "--audio" ]]; then
  AUDIO_DEVICE=$(ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep "audio" | head -1 | sed 's/.*\[\([0-9]*\).*\[.*/\1/' || echo "0")
  FFMPEG_ARGS=(-f avfoundation -framerate 30 -capture_cursor 1 -i "$SCREEN_DEVICE:$AUDIO_DEVICE" -c:v h264_videotoolbox -preset medium -c:a aac -pix_fmt yuv420p "$OUTPUT")
fi

echo "Starting capture session: $NAME"
echo "Recording..."

# Start FFmpeg in foreground; Ctrl+C stops it
"${FFMPEG_ARGS[@]}"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 255 ]; then
  # Create a minimal recording.db marker
  echo "recording:$NAME" > "$DB"

  # Create a viewer HTML for guest-local playback
  cat > "$VIEWER" <<HTMLEOF
<!DOCTYPE html>
<html>
<head><title>$NAME</title></head>
<body style="margin:0;background:#000">
<video controls autoplay style="width:100%;height:100%" src="recording.mp4"></video>
</body>
</html>
HTMLEOF

  echo "Recording saved: $NAME"
fi
