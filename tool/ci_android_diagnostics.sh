#!/bin/sh
# Saves what the CI emulator knows after a failed device test run, for the
# android-test-reports artifact (.github/workflows/android.yml). The full
# logcat is captured from the start of the run separately.
device=emulator-5554
out=app/build/ci-diagnostics
mkdir -p "$out"
adb -s "$device" logcat -d -v threadtime > "$out/logcat-at-failure.txt" 2>&1
adb -s "$device" shell pm list packages -3 -U > "$out/packages.txt" 2>&1
adb -s "$device" shell pm list users > "$out/users.txt" 2>&1
adb -s "$device" shell dumpsys package dev.flutterpoc.field_inspections > "$out/dumpsys-package.txt" 2>&1
adb -s "$device" shell getprop > "$out/getprop.txt" 2>&1
echo "Diagnostics saved in $out"
