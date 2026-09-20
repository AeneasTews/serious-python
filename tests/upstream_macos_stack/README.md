# Official macOS worker-stack probe

On a Mac with Flutter, Xcode, and CocoaPods installed, run from this repository:

```sh
bash tests/upstream_macos_stack/run.sh
```

The script creates a disposable Flutter project under your temporary directory,
pins the published `serious_python` 4.7.0 package and Python 3.12, packages NumPy
1.26.4, and launches the app on macOS. It does **not** use this repository's
Serious Python fork or the proposed `dart-bridge` PR.

Look for `STACK_PROBE_RESULT: stack_bytes=… numpy=ok`. The stack measurement is
taken inside the actual Python worker before NumPy is imported. A stack below
8,388,608 bytes means the published runtime lacks the proposed 8 MiB default.
If NumPy reports an error or the app crashes after printing
`STACK_PROBE_STACK_BYTES`, the failure is reproduced. If NumPy succeeds with a
smaller stack, this workload does not reproduce the crash; the size still shows
how much stack headroom the current release provides.

The script leaves the generated project and `run.log` in the printed temporary
directory so a crash can be inspected. Send back the `STACK_PROBE_` lines and
your Mac's architecture (`uname -m`).
