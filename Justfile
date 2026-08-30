# Justfile — single entry point for simulation, synth-check and lint.
# Used identically by a human in a terminal, by the VS Code tasks
# (.vscode/tasks.json), and by CI (.github/workflows/ci.yml) — no
# logic lives only in one of those places.
#
# Install: https://github.com/casey/just
# List all recipes: `just --list`

# All currently existing modules (rtl/<name>.sv + tb/tb_<name>.sv).
# Extend this list as new modules are added (see ROADMAP.md).
modules := "uart_tx"

# Default recipe: show what's available.
default:
    @just --list

# Compile + simulate one module's self-checking testbench.
# Fails (non-zero exit) if any check inside the testbench fails.
sim MODULE:
    iverilog -g2012 -o {{MODULE}}.vvp rtl/{{MODULE}}.sv tb/tb_{{MODULE}}.sv
    vvp {{MODULE}}.vvp

# Simulate, then open the recorded waveform in GTKWave.
wave MODULE: (sim MODULE)
    gtkwave tb_{{MODULE}}.vcd

# Generic synthesis check with Yosys — no FPGA board needed, just
# confirms the module synthesizes and reports a cell/area summary.
synth MODULE:
    yosys -p "read_verilog -sv rtl/{{MODULE}}.sv; synth -top {{MODULE}}; stat"

# Static lint with Verilator (independent of the Verible extension used
# for editor formatting — different tool, catches different issues).
# No C++ compiler required, this only elaborates and checks.
# (see scripts/verilator.sh for why this isn't a plain `verilator` call)
lint MODULE:
    ./scripts/verilator.sh --lint-only -Wall --top-module {{MODULE}} rtl/{{MODULE}}.sv

# Run lint + sim + synth-check for every module. This is what CI runs.
ci:
    #!/usr/bin/env bash
    set -euo pipefail
    for m in {{modules}}; do
        echo "=== $m: lint ==="
        just lint "$m"
        echo "=== $m: sim ==="
        just sim "$m"
        echo "=== $m: synth ==="
        just synth "$m"
    done

# Remove all simulation/build artifacts.
clean:
    rm -rf *.vvp *.vcd obj_dir
