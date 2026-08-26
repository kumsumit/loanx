#!/usr/bin/env bash

set -u

ADB_BIN="$(command -v adb 2>/dev/null || true)"
if [[ -z "$ADB_BIN" ]]; then
  ADB_BIN="$HOME/Library/Android/sdk/platform-tools/adb"
fi

if [[ ! -x "$ADB_BIN" ]]; then
  echo "adb was not found. Install Android SDK Platform Tools first." >&2
  exit 1
fi

TCP_PORT="${ADB_WIFI_PORT:-5555}"

echo "Starting ADB..."
"$ADB_BIN" start-server >/dev/null

mapfile_compat() {
  USB_DEVICES=()
  while IFS= read -r serial; do
    [[ -n "$serial" ]] && USB_DEVICES+=("$serial")
  done < <("$ADB_BIN" devices -l | awk '$2 == "device" && $3 ~ /^usb:/ {print $1}')
}

mapfile_compat

if [[ ${#USB_DEVICES[@]} -eq 0 ]]; then
  echo "No authorized USB Android device found." >&2
  echo "Connect the phone by cable, unlock it, and accept the USB debugging prompt." >&2
  exit 1
fi

SERIAL="${1:-}"
if [[ -n "$SERIAL" ]]; then
  FOUND=false
  for device in "${USB_DEVICES[@]}"; do
    [[ "$device" == "$SERIAL" ]] && FOUND=true
  done
  if [[ "$FOUND" != true ]]; then
    echo "USB device '$SERIAL' was not found." >&2
    exit 1
  fi
elif [[ ${#USB_DEVICES[@]} -eq 1 ]]; then
  SERIAL="${USB_DEVICES[0]}"
else
  echo "Multiple USB devices found:"
  for i in "${!USB_DEVICES[@]}"; do
    details="$("$ADB_BIN" -s "${USB_DEVICES[$i]}" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
    printf '  %d) %s  %s\n' "$((i + 1))" "${USB_DEVICES[$i]}" "$details"
  done

  read -r -p "Select a device [1-${#USB_DEVICES[@]}]: " selection
  if ! [[ "$selection" =~ ^[0-9]+$ ]] || (( selection < 1 || selection > ${#USB_DEVICES[@]} )); then
    echo "Invalid selection." >&2
    exit 1
  fi
  SERIAL="${USB_DEVICES[$((selection - 1))]}"
fi

PHONE_IP="$("$ADB_BIN" -s "$SERIAL" shell ip -4 route 2>/dev/null \
  | tr -d '\r' \
  | awk '/ dev wlan0 / {for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}')"

if [[ -z "$PHONE_IP" ]]; then
  echo "Could not determine the phone's Wi-Fi IP." >&2
  echo "Make sure Wi-Fi is enabled and the Mac and phone use the same network." >&2
  exit 1
fi

echo "Selected device: $SERIAL"
echo "Phone Wi-Fi IP: $PHONE_IP"
echo "Enabling ADB TCP mode on port $TCP_PORT..."

if ! "$ADB_BIN" -s "$SERIAL" tcpip "$TCP_PORT"; then
  echo "Failed to enable ADB TCP mode." >&2
  exit 1
fi

TARGET="$PHONE_IP:$TCP_PORT"
for attempt in 1 2 3 4 5; do
  echo "Connecting to $TARGET (attempt $attempt/5)..."
  "$ADB_BIN" connect "$TARGET" || true
  if "$ADB_BIN" devices | awk -v target="$TARGET" '$1 == target && $2 == "device" {found=1} END {exit !found}'; then
    echo
    echo "Wireless ADB connected successfully: $TARGET"
    echo "You can now unplug the USB cable."
    echo "Use: adb -s $TARGET shell"
    exit 0
  fi
  sleep 1
done

echo "Unable to establish wireless ADB at $TARGET." >&2
echo "Check that both devices are on the same Wi-Fi and that VPN/client isolation is disabled." >&2
exit 1
