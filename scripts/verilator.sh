#!/usr/bin/env bash
# Runs Verilator, working around a Windows-specific issue: the OSS CAD
# Suite ships `verilator` as a Perl wrapper script that sets
# VERILATOR_ROOT and execs the real compiled binary. On Windows, the
# suite's bundled minimal Perl is missing the Pod::Usage core module,
# so the wrapper crashes before doing anything useful. Fix: call the
# compiled binary directly and set VERILATOR_ROOT ourselves (what the
# wrapper would normally do). On Linux (e.g. `apt install verilator`
# in CI), the plain wrapper works fine as-is, so we just fall back to
# it there.
set -euo pipefail

find_bin() {
    command -v "$1" 2>/dev/null || true
}

bin="$(find_bin verilator_bin.exe)"
[ -z "$bin" ] && bin="$(find_bin verilator_bin)"

if [ -n "$bin" ]; then
    export VERILATOR_ROOT="${VERILATOR_ROOT:-$(dirname "$bin")/../share/verilator}"
    exec "$bin" "$@"
else
    exec verilator "$@"
fi
