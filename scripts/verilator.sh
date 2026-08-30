#!/usr/bin/env bash
# Resolves and runs a Verilator tool (verilator / verilator_coverage).
#
# Why this exists: the OSS CAD Suite ships these as Perl wrapper
# scripts that set VERILATOR_ROOT and exec the real compiled binary.
# On Windows, the suite's bundled minimal Perl is missing the
# Pod::Usage core module, so the wrapper crashes before doing anything
# useful. Fix: call the compiled binary directly and set VERILATOR_ROOT
# ourselves (what the wrapper would normally do). On Linux (e.g. `apt
# install verilator` in CI), the plain wrapper works fine as-is, so we
# just fall back to it there.
set -euo pipefail

tool="$1"; shift

find_bin() {
    command -v "$1" 2>/dev/null || true
}

bin=""
case "$tool" in
    verilator)
        bin="$(find_bin verilator_bin.exe)"
        [ -z "$bin" ] && bin="$(find_bin verilator_bin)"
        ;;
    verilator_coverage)
        bin="$(find_bin verilator_coverage_bin.exe)"
        [ -z "$bin" ] && bin="$(find_bin verilator_coverage_bin_dbg.exe)"
        [ -z "$bin" ] && bin="$(find_bin verilator_coverage_bin)"
        ;;
    *)
        echo "verilator.sh: unknown tool '$tool' (expected verilator or verilator_coverage)" >&2
        exit 1
        ;;
esac

if [ -n "$bin" ]; then
    export VERILATOR_ROOT="${VERILATOR_ROOT:-$(dirname "$bin")/../share/verilator}"
    exec "$bin" "$@"
else
    exec "$tool" "$@"
fi
