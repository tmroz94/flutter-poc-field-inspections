#!/usr/bin/env bash
# One-command quality gate (macOS / Linux): format, analyze and test every package.
# Usage: tool/check.sh [--coverage]
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
failed=()

step() {
  local name="$1" dir="$2"; shift 2
  printf '\n== %s ==\n' "$name"
  (cd "$root/$dir" && "$@") || failed+=("$name")
}

step 'format' . fvm dart format --output=none --set-exit-if-changed app/lib app/test packages/mock_data/lib packages/mock_data/test mock_server/lib mock_server/bin mock_server/test
step 'mock_data: analyze' packages/mock_data fvm dart analyze --fatal-infos
step 'mock_data: test' packages/mock_data fvm dart test
step 'mock_server: analyze' mock_server fvm dart analyze --fatal-infos
step 'mock_server: test' mock_server fvm dart test
step 'app: analyze' app fvm flutter analyze --fatal-infos
if [[ "${1:-}" == "--coverage" ]]; then
  step 'app: test' app fvm flutter test --coverage
else
  step 'app: test' app fvm flutter test
fi

if ((${#failed[@]})); then printf '\nFAILED: %s\n' "${failed[*]}"; exit 1; fi
printf '\nAll checks passed.\n'
