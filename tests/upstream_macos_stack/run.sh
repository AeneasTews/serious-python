#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Run this probe on macOS."
  exit 2
fi

probe_source="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/serious-python-stack.XXXXXX")"
echo "Probe project: $probe_dir"

flutter create --platforms=macos --project-name serious_python_stack_probe "$probe_dir"
cp "$probe_source/main.dart" "$probe_dir/lib/main.dart"
mkdir -p "$probe_dir/app/src"
cp "$probe_source/main.py" "$probe_dir/app/src/main.py"
if [[ -f "$probe_dir/macos/Podfile" ]]; then
  sed -i '' "s/platform :osx, '10.15'/platform :osx, '11.0'/" \
    "$probe_dir/macos/Podfile"
fi
sed -i '' 's/MACOSX_DEPLOYMENT_TARGET = 10.15;/MACOSX_DEPLOYMENT_TARGET = 11.0;/' \
  "$probe_dir/macos/Runner.xcodeproj/project.pbxproj"

cd "$probe_dir"
flutter pub add serious_python:4.7.0

export SERIOUS_PYTHON_VERSION=3.12
export SERIOUS_PYTHON_SITE_PACKAGES="$probe_dir/build/site-packages"
export SERIOUS_PYTHON_APP="$probe_dir/build/python-app"
dart run serious_python:main package app/src -p Darwin -r numpy==1.26.4

set +e
flutter run -d macos --release --no-pub 2>&1 | tee "$probe_dir/run.log"
run_status=${PIPESTATUS[0]}
set -e

echo
echo "Probe output:"
grep 'STACK_PROBE_' "$probe_dir/run.log" || true
echo "Full log: $probe_dir/run.log"

if ! grep -q 'STACK_PROBE_RESULT:' "$probe_dir/run.log"; then
  echo "No final result. Check the log for a native crash or packaging error."
  exit 1
fi
exit "$run_status"
