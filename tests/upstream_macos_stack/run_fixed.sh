#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Run this probe on macOS."
  exit 2
fi

if [[ $# -ne 1 ]]; then
  echo "Usage: bash tests/upstream_macos_stack/run_fixed.sh /path/to/previous/probe-project"
  exit 2
fi

probe_dir="$(cd "$1" && pwd -P)"
app_path="$probe_dir/build/macos/Build/Products/Release/serious_python_stack_probe.app"
if [[ ! -d "$app_path" ]]; then
  echo "No built release app at $app_path. Run run.sh first."
  exit 1
fi

framework="$(find "$app_path/Contents" -type d -name dart_bridge.framework -print -quit)"
if [[ -z "$framework" ]]; then
  echo "Cannot find dart_bridge.framework inside $app_path"
  exit 1
fi
if [[ -f "$framework/Versions/A/dart_bridge" ]]; then
  framework_binary="$framework/Versions/A/dart_bridge"
else
  framework_binary="$framework/dart_bridge"
fi
if [[ ! -f "$framework_binary" ]]; then
  echo "Cannot find the embedded dart_bridge binary in $framework"
  exit 1
fi

bridge_dir="$probe_dir/dart-bridge-stack-fix"
if [[ ! -d "$bridge_dir/.git" ]]; then
  git clone --depth 1 --branch fix/macos-python-worker-stack \
    https://github.com/AeneasTews/dart-bridge.git "$bridge_dir"
fi
expected_commit=09c2f5714c28941944a4c338e6581828140e9185
actual_commit="$(git -C "$bridge_dir" rev-parse HEAD)"
if [[ "$actual_commit" != "$expected_commit" ]]; then
  echo "Expected bridge PR commit $expected_commit; found $actual_commit"
  exit 1
fi

headers_tar="$probe_dir/python-ios-dart-3.12.tar.gz"
headers_tree="$probe_dir/python-ios-headers"
if [[ ! -f "$headers_tar" ]]; then
  curl -fL -o "$headers_tar" \
    https://github.com/flet-dev/python-build/releases/download/v3.12/python-ios-dart-3.12.tar.gz
fi
if [[ ! -d "$headers_tree" ]]; then
  mkdir -p "$headers_tree"
  tar -xzf "$headers_tar" -C "$headers_tree"
fi
python_header="$(find "$headers_tree" -name Python.h -type f -print -quit)"
if [[ -z "$python_header" ]]; then
  echo "Python.h was not found in $headers_tar"
  exit 1
fi
export PYTHON_HEADERS_DIR="$(dirname "$python_header")"

patched_binary="$probe_dir/patched-dart_bridge.dylib"
macos_sdk="$(xcrun --sdk macosx --show-sdk-path)"
xcrun --sdk macosx clang \
  -arch "$(uname -m)" \
  -isysroot "$macos_sdk" \
  -mmacosx-version-min=11.0 \
  -DPy_LIMITED_API=0x030c0000 \
  -DDART_SHARED_LIB \
  -fvisibility=hidden \
  -I "$PYTHON_HEADERS_DIR" \
  -I "$bridge_dir/src" \
  -dynamiclib \
  -install_name '@rpath/dart_bridge.framework/dart_bridge' \
  -Wl,-undefined,dynamic_lookup \
  "$bridge_dir/src/dart_bridge.c" \
  "$bridge_dir/src/serious_python_run.c" \
  "$bridge_dir/src/dart_api/dart_api_dl.c" \
  -o "$patched_binary"

# Keep the originally embedded binary recoverable outside the signed bundle.
upstream_backup="$probe_dir/dart_bridge.upstream"
if [[ ! -f "$upstream_backup" ]]; then
  cp "$framework_binary" "$upstream_backup"
fi
chmod u+w "$framework_binary"
cp "$patched_binary" "$framework_binary"
cmp "$patched_binary" "$framework_binary"
codesign --force --sign - "$framework"
codesign --force --deep --sign - "$app_path"
codesign --verify --deep "$app_path"

echo "Running with patched bridge commit $actual_commit"
set +e
"$app_path/Contents/MacOS/serious_python_stack_probe" 2>&1 | \
  tee "$probe_dir/fixed-run.log"
run_status=${PIPESTATUS[0]}
set -e

echo
echo "Patched probe output:"
grep 'STACK_PROBE_' "$probe_dir/fixed-run.log" || true
echo "Full log: $probe_dir/fixed-run.log"
if ! grep -q 'STACK_PROBE_RESULT:' "$probe_dir/fixed-run.log"; then
  echo "No final result from the patched app."
  exit 1
fi
exit "$run_status"
