#!/bin/sh
# Saves what the CI emulator knows after a failed device test run, for the
# android-test-reports artifact (.github/workflows/android.yml). The full
# logcat is captured from the start of the run separately. Every adb call has
# a time limit: in run 41486170144 the emulator had died, and the failure path
# hung until the job timed out, so nothing was uploaded.
device=emulator-5554
out=app/build/ci-diagnostics
mkdir -p "$out"
timeout 30 adb devices -l >"$out/devices.txt" 2>&1
timeout 60 adb -s "$device" logcat -d -v threadtime > "$out/logcat-at-failure.txt" 2>&1
timeout 30 adb -s "$device" shell pm list packages -3 -U > "$out/packages.txt" 2>&1
timeout 30 adb -s "$device" shell pm list users > "$out/users.txt" 2>&1
timeout 30 adb -s "$device" shell dumpsys package dev.flutterpoc.field_inspections > "$out/dumpsys-package.txt" 2>&1
timeout 30 adb -s "$device" shell getprop > "$out/getprop.txt" 2>&1
# The emulator's own crash reports, when the emulator process died.
cp -r /tmp/android-runner "$out/emulator-crashes" 2>/dev/null
# The runner's side: its memory now, the largest processes, and whether the
# kernel's OOM killer ended one (the emulator vanished in run 41513210914).
free -m > "$out/host-free.txt" 2>&1
ps -eo pid,rss,etime,args --sort=-rss | head -15 | cut -c1-200 > "$out/host-processes.txt" 2>&1
timeout 30 sudo dmesg -T 2>&1 | grep -i -E "oom|killed process" > "$out/host-oom.txt"
echo "Diagnostics saved in $out"
