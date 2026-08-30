# UART / SPI / I2C Controller

[![CI](https://github.com/OWNER/uart-controller/actions/workflows/ci.yml/badge.svg)](https://github.com/OWNER/uart-controller/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> Platzhalter `OWNER` im Badge-Link oben durch den tatsächlichen
> GitHub-Benutzernamen ersetzen, sobald das Repo dort liegt.

Lern- und Portfolio-Projekt: drei klassische serielle Peripherie-Controller
(UART, SPI, I2C) in SystemVerilog, jeweils als eigenständiger, sauber
verifizierter IP-Block nach demselben Muster gebaut. Kein gemeinsamer
Bus-Rahmen von Anfang an — die Begründung dafür sowie der aktuelle
Baustand stehen in [ROADMAP.md](ROADMAP.md).

Aktueller Stand: `uart_tx` (Transmitter, 8N1) ist fertig, verifiziert und
synthese-sauber. Alles Weitere — `uart_rx`, `spi_master`, `i2c_master`,
Hardware-Bring-up auf einem Digilent Basys 3 — ist in Arbeit, siehe
[ROADMAP.md](ROADMAP.md) für Phasenplan und offene Design-Fragen.

## Repository-Struktur

```
uart-controller/
├── .github/
│   ├── workflows/ci.yml    # Lint + Simulation + Synth-Check + Coverage
│   ├── ISSUE_TEMPLATE/
│   └── pull_request_template.md
├── .vscode/
│   ├── settings.json       # Formatierung (Verible), Datei-Zuordnung .sv/.svh
│   ├── tasks.json          # ruft dieselben `just`-Recipes wie Terminal/CI auf
│   └── extensions.json     # empfohlene Extensions
├── rtl/
│   └── uart_tx.sv          # UART-Transmitter (8N1)
├── tb/
│   └── tb_uart_tx.sv       # Self-checking Testbench
├── scripts/
│   └── verilator.sh        # Windows/Linux-Kompatibilitätsshim für Verilator
├── Justfile                 # zentraler Einstiegspunkt: sim/wave/synth/lint/coverage/ci
├── LICENSE
├── ROADMAP.md               # Phasenplan, offene Fragen, Definition of Done
└── README.md
```

Jedes weitere Modul kommt als `rtl/<name>.sv` + `tb/tb_<name>.sv` in
dieselben Ordner dazu — kein Unterordner pro Protokoll, solange die
Modulanzahl überschaubar bleibt (siehe [ROADMAP.md](ROADMAP.md) für den
geplanten Umstieg auf FuseSoC, sobald das nicht mehr reicht). Neue Module
werden zusätzlich in der `modules`-Variable im `Justfile` eingetragen,
damit `just ci` und die CI-Pipeline sie automatisch mit erfassen.

## Werkzeuge

Drei bewusst getrennte Ebenen:

**1. Simulation, Lint & Synthese-Check — reproduzierbar per CLI, das
eigentliche Fundament des Projekts:**

- [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)
  (`iverilog`, `vvp`, `yosys`, `gtkwave`, `verilator`) — Open-Source-
  Toolchain, komplett ohne FPGA-Board nutzbar.
- [`just`](https://github.com/casey/just) als Command-Runner —
  `Justfile` ist der Single Point of Truth für alle Recipes (siehe
  [Workflow](#workflow)). Dieselben Recipes laufen im Terminal, aus den
  VS-Code-Tasks und in der GitHub-Actions-CI — daran hängt bewusst
  nichts Editor-Spezifisches.

**2. Editor-Komfort in VS Code — Linting, Navigation, Formatierung:**

- [TerosHDL](https://marketplace.visualstudio.com/items?itemName=teros-technology.teroshdl)
  (`teros-technology.teroshdl`) für Linting, Sprungmarken/Hover und
  Projektübersicht.
- [Verible](https://marketplace.visualstudio.com/items?itemName=chipsalliance.verible)
  (`chipsalliance.verible`) als Formatter (`editor.formatOnSave`).
- Beide werden beim Öffnen des Ordners als Empfehlung vorgeschlagen
  (`.vscode/extensions.json`).

**3. CI — dieselben Recipes automatisiert bei jedem Push/PR:**
siehe [CI](#ci) unten.

Diese Trennung ist bewusst: Ebene 1 funktioniert unabhängig davon, wer
welche Editor-Extension installiert hat, und ist identisch zu dem, was
CI ausführt. TerosHDL/Verible verbessern nur die Arbeit *im* Editor,
ersetzen die Recipes aber nicht.

### Installation OSS CAD Suite (Windows)

1. Aktuelles Release von [oss-cad-suite-build](https://github.com/YosysHQ/oss-cad-suite-build/releases)
   herunterladen und entpacken, z.B. nach `C:\oss-cad-suite`.
2. `bin\` **und** `lib\` des Suite-Ordners zum PATH hinzufügen
   (`lib\` liefert Laufzeit-Plugins wie `system.vpi`, ohne die scheitert
   `vvp` mit einer irreführenden Fehlermeldung) — entweder dauerhaft über
   die Windows-Systemumgebungsvariablen, oder pro Terminal-Sitzung über
   `environment.bat` / `environment.ps1` im Suite-Ordner.
3. **Windows-Falle:** Nach ZIP/TGZ-Download tragen alle entpackten
   Dateien das "Mark of the Web" (Zone.Identifier). Windows blockiert
   dann das Laden der Plugins mit einer Meldung wie
   `Failed to open '...system.vpi' because: The operation completed
   successfully.`. Fix in PowerShell:
   ```powershell
   Get-ChildItem C:\oss-cad-suite -Recurse -File | Unblock-File
   ```
4. **Windows-Falle 2:** Die von der OSS CAD Suite mitgelieferten
   `verilator`/`verilator_coverage`-Befehle sind Perl-Wrapper-Skripte;
   das mitgelieferte Minimal-Perl auf Windows besitzt aber kein
   `Pod::Usage`-Modul, wodurch die Wrapper sofort abstürzen. `just lint`
   und `just coverage` rufen deshalb `scripts/verilator.sh` auf, das
   stattdessen die kompilierte Binary (`verilator_bin.exe`) direkt mit
   passend gesetztem `VERILATOR_ROOT` aufruft. Unter Linux (z.B. in CI
   via `apt install verilator`) ist der reguläre `verilator`-Befehl
   vollständig, der Shim nutzt dort einfach diesen.
5. [`just`](https://github.com/casey/just#installation) installieren
   (z.B. `winget install --id Casey.Just`).

## Workflow

Alles läuft über `just` — im Terminal, aus VS Code, oder in CI.

```
just --list          # alle Recipes anzeigen
just sim uart_tx      # kompilieren + self-checking Testbench laufen lassen
just wave uart_tx      # wie sim, öffnet danach die Waveform in GTKWave
just synth uart_tx     # generischer Yosys-Synth-Check, kein Board nötig
just lint uart_tx      # Verilator --lint-only (zweiter, unabhängiger Linter)
just coverage uart_tx  # Line-/Toggle-Coverage via Verilator (siehe Coverage)
just ci                # lint + sim + synth für alle Module in `modules`
```

In VS Code (Ordner öffnen mit `code .` oder "Datei → Ordner öffnen")
rufen die Tasks in `.vscode/tasks.json` dieselben Recipes auf:

- **Strg+Umschalt+B** (Default Build Task) → `just sim uart_tx`.
- **Terminal → Task ausführen…** → alle anderen Recipes, für ein
  abgefragtes Modul (`Simulate`, `Waveform`, `Synth-Check`, `Lint`,
  `Coverage`) oder als Sammel-Task (`CI: alle Module`).

Beim Speichern einer `.sv`-Datei formatiert Verible automatisch,
TerosHDL zeigt Lint-Hinweise inline im Editor an.

## Tests, Lint & Coverage

**Self-checking Testbenches** (`just sim <modul>`): kein manuelles
Ablesen von Waveforms nötig — `ALL CHECKS PASSED` bzw. `N CHECK(S)
FAILED` am Ende des Laufs, und die Simulation beendet sich bei einem
fehlgeschlagenen Check über `$fatal` mit Exit-Code ≠ 0 (nicht `$finish`),
damit ein fehlschlagender Test auch tatsächlich die CI rot macht. Jede
Testbench folgt demselben Muster: Synchronisation auf eine von außen
beobachtbare Flanke oder Bedingung des jeweiligen Protokolls (z.B. die
fallende Flanke des Start-Bits bei UART), danach bitweises Abtasten am
Signal-Mid-Point und Vergleich gegen den Erwartungswert — genau so, wie
ein echter Empfänger/Slave das tun würde. Das macht die Prüfung
unabhängig davon, wie viele interne Taktzyklen die FSM des DUT für
einen Zustandsübergang tatsächlich braucht.

**Lint** (`just lint <modul>`): Verilator im `--lint-only`-Modus als
zweiter, von Verible unabhängiger statischer Checker — braucht keinen
C++-Compiler, läuft überall dort, wo auch simuliert wird.

**Coverage** (`just coverage <modul>`): Line- und Toggle-Coverage über
Verilator (`--coverage`, echtes verilatetes Executable). Das braucht
zusätzlich einen C++-Compiler + `make` zum Linken — auf dem
GitHub-Actions-`ubuntu-latest`-Runner standardmäßig vorhanden, auf
Windows lokal aber **nicht** ohne separat installiertes
MinGW-w64/MSYS2. Dieser Recipe ist deshalb aktuell CI-verifiziert
(siehe [CI](#ci)), aber nicht auf jeder lokalen Windows-Maschine ohne
Weiteres lauffähig — das ist eine bewusste Lücke, kein Bug.

## CI

`.github/workflows/ci.yml` läuft bei jedem Push auf `main` und bei
jedem Pull Request, mit zwei Jobs:

1. **`lint-sim-synth`** — installiert `iverilog`/`yosys`/`verilator`
   via `apt`, dann `just ci` (Lint + Simulation + Synth-Check für alle
   Module). Das ist das eigentliche Gate.
2. **`coverage`** — installiert zusätzlich `build-essential`, läuft
   `just coverage` für jedes Modul und lädt den annotierten
   Coverage-Report als Workflow-Artifact hoch.

Beide Jobs nutzen exakt dieselben `Justfile`-Recipes wie die lokale
Kommandozeile — es gibt keine Logik, die nur in der CI-YAML oder nur
lokal existiert.

## Module

### `uart_tx` — UART-Transmitter (8N1)

| Signal      | Richtung | Beschreibung                              |
|-------------|----------|--------------------------------------------|
| `clk`       | in       | Systemtakt                                 |
| `rst_n`     | in       | aktiv-Low, synchron                        |
| `tx_valid`  | in       | 1 Takt hoch = neues Byte übernehmen        |
| `tx_data`   | in       | zu sendendes Byte                          |
| `tx_ready`  | out      | high, wenn ein neues Byte angenommen wird  |
| `tx_serial` | out      | serielle Leitung, idle = high              |

`CLK_FREQ_HZ` und `BAUD_RATE` sind Parameter — Standard ist 50 MHz /
115200 Baud, in der Testbench genauso gesetzt.

Weitere Module (`uart_rx`, `spi_master`, `i2c_master`) folgen mit
derselben Interface-Dokumentation, sobald sie den in ROADMAP.md
definierten "Definition of Done"-Status erreichen.

## Roadmap

Phasenplan, offene Design-Fragen pro Modul (SPI-Modi, I2C Clock
Stretching, UART-Oversampling, …), Definition of Done und der
Basys-3-Hardware-Fahrplan stehen in [ROADMAP.md](ROADMAP.md).

## Lizenz

[MIT](LICENSE)
