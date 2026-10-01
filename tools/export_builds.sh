#!/usr/bin/env bash
# Exports the web build and the Android APK into GameDevAsset/builds/.
#
#   web:     builds/web/index.html (+ .js, .wasm, .pck): open it from any web
#            host; it is single-threaded, so it needs no special server headers
#   android: builds/android/the-twelfth-moon.apk, signed with the release key
#
# Needs Godot 4.7.2 with its export templates installed, and for Android the
# JDK and SDK set in Godot's editor settings plus the key in
# GameDevAsset/android-signing/ (see its README). Run from the project folder:
#   bash tools/export_builds.sh [web|android]   (both when no argument)
set -euo pipefail

GODOT="${GODOT:-C:/Users/knrib/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
SIGNING="../android-signing"
which="${1:-all}"

mkdir -p ../builds/web ../builds/android

if [[ "$which" == "all" || "$which" == "web" ]]; then
	"$GODOT" --headless --path . --export-release "Web" ../builds/web/index.html
fi

if [[ "$which" == "all" || "$which" == "android" ]]; then
	GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(cd "$SIGNING" && pwd -W)/the-twelfth-moon.keystore" \
	GODOT_ANDROID_KEYSTORE_RELEASE_USER="twelfthmoon" \
	GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(cat "$SIGNING/keystore-password.txt")" \
		"$GODOT" --headless --path . --export-release "Android" \
		../builds/android/the-twelfth-moon.apk
fi

ls -l ../builds/web ../builds/android
