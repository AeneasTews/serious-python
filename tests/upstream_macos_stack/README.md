# Official macOS worker-stack probe

On a Mac with Flutter, Xcode, and CocoaPods installed, run from this repository:

```sh
bash tests/upstream_macos_stack/run.sh
```

The script creates a disposable Flutter project under your temporary directory,
pins the published `serious_python` 4.7.0 package and Python 3.12, packages NumPy
1.26.4, and launches the app on macOS. It does **not** use this repository's
Serious Python fork or the proposed `dart-bridge` PR. Recent Flutter templates
use Swift Package Manager and may have no `macos/Podfile`; the script supports
both layouts.

Look for `STACK_PROBE_RESULT: stack_bytes=… numpy=ok`. The stack measurement is
taken inside the actual Python worker before NumPy is imported. A stack below
8,388,608 bytes means the published runtime lacks the proposed 8 MiB default.
If NumPy reports an error or the app crashes after printing
`STACK_PROBE_STACK_BYTES`, the failure is reproduced. The worker waits until
Flutter has printed the stack size before importing NumPy. If NumPy succeeds with a
smaller stack, this workload does not reproduce the crash; the size still shows
how much stack headroom the current release provides.

The script leaves the generated project and `run.log` in the printed temporary
directory so a crash can be inspected. Send back the `STACK_PROBE_` lines and
your Mac's architecture (`uname -m`).

To test the proposed fix in the **same built app**, run:

```sh
bash tests/upstream_macos_stack/run_fixed.sh /path/printed/by/run.sh
```

This fetches the exact [draft PR commit](https://github.com/flet-dev/dart-bridge/pull/21),
builds its macOS bridge binary for your machine, replaces the binary inside that
temporary release app, re-signs the app for local execution, and runs the same
Python/NumPy probe. The published package, your Flutter installation, and the
shared Flet cache are untouched. The original embedded bridge binary is saved
as `dart_bridge.upstream` in the temporary project directory.

A successful fixed run should print at least 8,388,608 stack bytes and
`numpy=ok`. This is a local smoke test using an ad-hoc signature and a
single-architecture binary; the upstream release still needs its full Apple
XCFramework and normal signed artifacts.
