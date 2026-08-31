# UART / SPI / I2C Controller

[![CI](https://github.com/fgulde/uart-spi-i2c-controller/actions/workflows/ci.yml/badge.svg)](https://github.com/fgulde/uart-spi-i2c-controller/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Learning / portfolio project: three classic serial peripheral
controllers (UART, SPI, I2C) in SystemVerilog, each built as a
self-contained, cleanly verified IP block following the same pattern.
No shared bus framework from the start — see [ROADMAP.md](ROADMAP.md)
*(in German)* for the reasoning and current status.

Current status: `uart_tx` (transmitter, 8N1) is done, verified, and
synthesizes cleanly. Everything else — `uart_rx`, `spi_master`,
`i2c_master`, hardware bring-up on a Digilent Basys 3 — is in progress,
see [ROADMAP.md](ROADMAP.md) *(in German)* for the phase plan and open
design questions.

## Repository structure

```
uart-spi-i2c-controller/
├── .github/
│   └── workflows/ci.yml    # lint + simulate + synth-check
├── .vscode/
│   ├── settings.json       # formatting (Verible), .sv/.svh file association
│   ├── tasks.json          # calls the same `just` recipes as terminal/CI
│   └── extensions.json     # recommended extensions
├── rtl/
│   └── uart_tx.sv          # UART transmitter (8N1)
├── tb/
│   └── tb_uart_tx.sv       # self-checking testbench
├── scripts/
│   └── verilator.sh        # Windows/Linux compatibility shim for Verilator
├── Justfile                 # central entry point: sim/wave/synth/lint/ci
├── LICENSE
├── ROADMAP.md               # phase plan, open questions, definition of done (German)
└── README.md
```

Every additional module goes into the same folders as `rtl/<name>.sv`
+ `tb/tb_<name>.sv` — no per-protocol subfolder as long as the module
count stays manageable (see [ROADMAP.md](ROADMAP.md) for the planned
move to FuseSoC once that stops being true). New modules also get
added to the `modules` variable in the `Justfile`, so `just ci` and
the CI pipeline pick them up automatically.

## Tooling

Three deliberately separate layers:

**1. Simulation, lint & synth-check — reproducible via CLI, the actual
foundation of the project:**

- [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)
  (`iverilog`, `vvp`, `yosys`, `gtkwave`, `verilator`) — open-source
  toolchain, fully usable without any FPGA board.
- [`just`](https://github.com/casey/just) as the command runner — the
  `Justfile` is the single source of truth for every recipe (see
  [Workflow](#workflow)). The same recipes run in a terminal, from the
  VS Code tasks, and in GitHub Actions CI — nothing here depends on
  the editor.

**2. Editor comfort in VS Code — linting, navigation, formatting:**

- [TerosHDL](https://marketplace.visualstudio.com/items?itemName=teros-technology.teroshdl)
  (`teros-technology.teroshdl`) for linting, go-to-definition/hover,
  and project overview.
- [Verible](https://marketplace.visualstudio.com/items?itemName=chipsalliance.verible)
  (`chipsalliance.verible`) as the formatter (`editor.formatOnSave`).
- Both are suggested as recommendations when the folder is opened
  (`.vscode/extensions.json`).

**3. CI — the same recipes, automated on every push/PR:** see
[CI](#ci) below.

This separation is deliberate: layer 1 works regardless of which
editor extensions anyone has installed, and is identical to what CI
runs. TerosHDL/Verible only improve the experience *inside* the
editor, they don't replace the recipes.

### Installing the OSS CAD Suite (Windows)

1. Download the current release of
   [oss-cad-suite-build](https://github.com/YosysHQ/oss-cad-suite-build/releases)
   and extract it, e.g. to `C:\oss-cad-suite`.
2. Add **both** `bin\` and `lib\` of the suite folder to PATH (`lib\`
   ships the runtime plugins loaded by `vvp`/`iverilog`, such as
   `system.vpi` — without it, `vvp` fails with a misleading error) —
   either permanently via the Windows system environment variables, or
   per terminal session via `environment.bat` / `environment.ps1` in
   the suite folder.
3. **Windows gotcha:** after extracting a downloaded ZIP/TGZ, every
   file carries the "Mark of the Web" (Zone.Identifier). Windows then
   blocks loading the plugins with an error like `Failed to open
   '...system.vpi' because: The operation completed successfully.`.
   Fix, in PowerShell:
   ```powershell
   Get-ChildItem C:\oss-cad-suite -Recurse -File | Unblock-File
   ```
4. **Windows gotcha #2:** the `verilator` command shipped with the OSS
   CAD Suite is a Perl wrapper script; the suite's bundled minimal
   Perl on Windows is missing the `Pod::Usage` core module, so the
   wrapper crashes immediately. `just lint` therefore calls
   `scripts/verilator.sh`, which instead invokes the compiled binary
   (`verilator_bin.exe`) directly with `VERILATOR_ROOT` set correctly.
   On Linux (e.g. in CI via `apt install verilator`) the regular
   `verilator` command works fine, so the shim just falls back to it
   there.
5. Install [`just`](https://github.com/casey/just#installation) (e.g.
   `winget install --id Casey.Just`).

## Workflow

Everything goes through `just` — in a terminal, from VS Code, or in
CI.

```
just --list          # list all recipes
just sim uart_tx      # compile + run the self-checking testbench
just wave uart_tx      # like sim, then opens the waveform in GTKWave
just synth uart_tx     # generic Yosys synth-check, no board needed
just lint uart_tx      # Verilator --lint-only (second, independent linter)
just ci                # lint + sim + synth for every module in `modules`
```

In VS Code (open the folder with `code .` or "File → Open Folder"),
the tasks in `.vscode/tasks.json` call the same recipes:

- **Ctrl+Shift+B** (default build task) → `just sim uart_tx`.
- **Terminal → Run Task…** → all other recipes, for a module you pick
  (`Simulate`, `Waveform`, `Synth-Check`, `Lint`) or as a bundled task
  (`CI: all modules`).

Saving a `.sv` file auto-formats via Verible; TerosHDL shows lint
hints inline in the editor.

## Tests & lint

**Self-checking testbenches** (`just sim <module>`): no manual
waveform reading needed — `ALL CHECKS PASSED` or `N CHECK(S) FAILED`
at the end of the run, and the simulation ends on a failed check via
`$fatal` with a non-zero exit code (not `$finish`), so a failing test
actually turns CI red. Every testbench follows the same pattern:
synchronize on an externally observable edge or condition of the
protocol in question (e.g. the falling edge of the start bit for
UART), then sample bit by bit at the signal's mid-point and compare
against the expected value — exactly like a real receiver/slave would.
That makes the check independent of how many internal clock cycles the
DUT's FSM actually takes for a state transition.

**Lint** (`just lint <module>`): Verilator in `--lint-only` mode as a
second static checker, independent of Verible — needs no C++
compiler, runs everywhere simulation does.

Deliberately **no** code coverage tooling: line/toggle coverage (e.g.
via Verilator) wouldn't be very meaningful for a module with a handful
of targeted, deterministic tests, and Icarus Verilog doesn't support
SystemVerilog's actual coverage-driven-verification feature —
`covergroup`/`coverpoint` for functional coverage, the centerpiece of
constrained-random verification (UVM) — anyway. Worth revisiting once
randomized tests are added, see ROADMAP.md.

## CI

`.github/workflows/ci.yml` runs on every push to `main` and every pull
request: installs `iverilog`/`yosys`/`verilator` via `apt`, then runs
`just ci` (lint + simulate + synth-check for every module). The exact
same `Justfile` recipes as locally — there's no logic that only exists
in the CI YAML or only locally.

## Modules

### `uart_tx` — UART transmitter (8N1)

| Signal      | Direction | Description                                |
|-------------|-----------|---------------------------------------------|
| `clk`       | in        | system clock                                |
| `rst_n`     | in        | active-low, synchronous                     |
| `tx_valid`  | in        | pulse high for 1 cycle to accept a new byte |
| `tx_data`   | in        | byte to transmit                            |
| `tx_ready`  | out       | high when a new byte can be accepted        |
| `tx_serial` | out       | serial line, idles high                     |

`CLK_FREQ_HZ` and `BAUD_RATE` are parameters — default is 50 MHz /
115200 baud, set the same way in the testbench.

Further modules (`uart_rx`, `spi_master`, `i2c_master`) will get the
same interface documentation once they reach the "definition of done"
status defined in ROADMAP.md.

## Roadmap

The phase plan, open design questions per module (SPI modes, I2C clock
stretching, UART oversampling, …), definition of done, and the Basys 3
hardware roadmap live in [ROADMAP.md](ROADMAP.md) *(in German — the
rest of this project is in English, but that's the one document kept
in the author's native language)*.

## License

[MIT](LICENSE)
