#!/usr/bin/env bash
# Builds the Linux app and runs the integration flows and the platform probe in
# a Linux container, from macOS (or any machine with Docker). The container
# matches the host's CPU (arm64 on Apple silicon), so this checks the Linux
# code, not the x64 binary CI builds.
# Usage: tool/linux_container/test.sh   (Docker running; first run builds the image)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
image=field-inspections-linux
name=field-inspections-linux-test

# Flutter at the version FVM pins for the project.
flutter_version="$(sed -n 's/.*"flutter": *"\([^"]*\)".*/\1/p' "$root/.fvmrc")"
docker build --build-arg FLUTTER_VERSION="$flutter_version" -t "$image" "$here"
docker rm -f "$name" > /dev/null 2>&1 || true
docker run -d --name "$name" "$image" sleep infinity > /dev/null
trap 'docker rm -f "$name" > /dev/null 2>&1 || true' EXIT

# A clean copy of the repository's files (tracked, plus new files that aren't
# ignored, so uncommitted work is tested too): build output and macOS
# metadata (._*) would break the Linux build.
# Files deleted but not yet committed are still listed: skip what isn't there.
(cd "$root" && git ls-files -co --exclude-standard | while IFS= read -r f; do [ -e "$f" ] && printf '%s\n' "$f"; done |
  COPYFILE_DISABLE=1 tar --no-xattrs -czf - -T -) |
  docker exec -i "$name" bash -c 'mkdir -p ~/repo && tar -xzf - -C ~/repo'

# Every file runs even after one fails (as in CI); the script fails at the end.
docker exec "$name" bash -c '
  set -e
  cd ~/repo/app
  flutter pub get > /dev/null
  flutter build linux --release
  status=0
  for f in app_test ui_flows_test platform_probe_test; do
    dbus-run-session -- xvfb-run -a -s "-screen 0 1440x900x24" flutter test integration_test/$f.dart -d linux || status=1
  done
  exit $status'
