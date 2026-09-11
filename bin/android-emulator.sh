#!/usr/bin/env bash

set -euo pipefail

# Override these with environment variables when needed, for example:
#   ANDROID_AVD_NAME=my-avd ./android-emulator.sh
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/Users/billfinn/Library/Android/sdk}}"
AVD_NAME="${ANDROID_AVD_NAME:-pixel-api-35}"
API_LEVEL="${ANDROID_API_LEVEL:-35}"
EMULATOR_PORT="${ANDROID_EMULATOR_PORT:-5554}"
DEVICE_SERIAL="emulator-${EMULATOR_PORT}"

case "$(uname -m)" in
  arm64|aarch64)
    ABI="arm64-v8a"
    ;;
  x86_64)
    ABI="x86_64"
    ;;
  *)
    echo "Unsupported host architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

SYSTEM_IMAGE="system-images;android-${API_LEVEL};google_apis;${ABI}"
SDKMANAGER="${SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager"
AVDMANAGER="${SDK_ROOT}/cmdline-tools/latest/bin/avdmanager"
EMULATOR="${SDK_ROOT}/emulator/emulator"
ADB="${SDK_ROOT}/platform-tools/adb"

for required_tool in "$SDKMANAGER" "$AVDMANAGER" "$EMULATOR" "$ADB"; do
  if [[ ! -x "$required_tool" ]]; then
    echo "Missing Android SDK tool: $required_tool" >&2
    echo "Set ANDROID_SDK_ROOT to the location of your Android SDK." >&2
    exit 1
  fi
done

if ! command -v scrcpy >/dev/null 2>&1; then
  echo "scrcpy is not installed or is not on PATH." >&2
  exit 1
fi

echo "Installing or verifying Android SDK components..."
"$SDKMANAGER" --licenses
"$SDKMANAGER" \
  "platform-tools" \
  "emulator" \
  "platforms;android-${API_LEVEL}" \
  "$SYSTEM_IMAGE"

if ! "$AVDMANAGER" list avd -c 2>/dev/null | grep -Fxq "$AVD_NAME"; then
  echo "Creating AVD: $AVD_NAME"
  echo "no" | "$AVDMANAGER" create avd \
    --name "$AVD_NAME" \
    --package "$SYSTEM_IMAGE" \
    --device "pixel_7" \
    --force
fi

"$ADB" start-server >/dev/null

device_is_listed() {
  "$ADB" devices | awk -v serial="$DEVICE_SERIAL" '$1 == serial { found = 1 } END { exit !found }'
}

if ! device_is_listed; then
  echo "Starting $AVD_NAME on $DEVICE_SERIAL..."
  emulator_log="${TMPDIR:-/tmp}/android-emulator-${EMULATOR_PORT}.log"
  "$EMULATOR" \
    -avd "$AVD_NAME" \
    -port "$EMULATOR_PORT" \
    -no-snapshot \
    >"$emulator_log" 2>&1 &
  echo "Emulator log: $emulator_log"
fi

echo "Waiting for $DEVICE_SERIAL to become available..."
device_ready=0
for _ in {1..180}; do
  if "$ADB" -s "$DEVICE_SERIAL" get-state >/dev/null 2>&1; then
    device_ready=1
    break
  fi
  sleep 1
done

if [[ "$device_ready" -ne 1 ]]; then
  echo "Timed out waiting for $DEVICE_SERIAL." >&2
  exit 1
fi

boot_completed=0
for _ in {1..300}; do
  if [[ "$("$ADB" -s "$DEVICE_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
    boot_completed=1
    break
  fi
  sleep 1
done

if [[ "$boot_completed" -ne 1 ]]; then
  echo "Timed out waiting for Android to finish booting on $DEVICE_SERIAL." >&2
  exit 1
fi

echo
echo "Android emulator is ready."
echo "Device serial: $DEVICE_SERIAL"
echo "export ANDROID_SERIAL=$DEVICE_SERIAL"
echo "Install an APK with: adb install -r path/to/app.apk"
echo

exec scrcpy --serial "$DEVICE_SERIAL"
