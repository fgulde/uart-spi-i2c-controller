# Roadmap

Dieses Dokument hält fest, wo das Projekt steht, wie es strukturiert weitergeht,
und welche Entscheidungen noch offen sind. Es ersetzt das "Nächste Schritte"-
Kapitel der README als lebendes Dokument — bei jedem Meilenstein aktualisieren.

## Ziel

Ein UART-, SPI- und I2C-Controller in SystemVerilog, als eigenständige,
sauber verifizierte IP-Blöcke — kein Bus-SoC-Rahmen von Anfang an, sondern
drei für sich funktionsfähige und portfoliotaugliche Module. Eine
Zusammenführung zu einem gemeinsamen, register-map-basierten Controller ist
als Stretch Goal denkbar, sobald alle drei Module stehen (siehe unten).

**Warum getrennte IP-Blöcke statt eines Bus-Controllers von Anfang an:**
schnellere sichtbare Fortschritte, jedes Modul ist einzeln vorzeigbar, und
die Bus-/Adressraum-Entscheidung (APB? Wishbone? eigenes Register-Interface?)
lässt sich fundierter treffen, wenn schon klar ist, welche Register/Signale
die drei Peripherien tatsächlich brauchen.

**Hardware-Fahrplan:** vorerst reine Simulation (Icarus Verilog) + generischer
Yosys-Synth-Check ohne Board. Mittelfristiges Ziel ist ein Digilent
**Basys 3** (Xilinx Artix-7 XC7A35T) mit Vivado für Bitstream und echtes
Board-Bring-up — siehe [Phase 5](#phase-5-basys-3-bring-up).

## Status Quo

| Modul        | RTL | Testbench | Synth-Check | Board-Bring-up |
|--------------|:---:|:---------:|:-----------:|:---------------:|
| `uart_tx`    | ✅  | ✅        | ✅          | —               |
| `uart_rx`    | ⬜  | ⬜        | ⬜          | —               |
| `spi_master` | ⬜  | ⬜        | ⬜          | —               |
| `i2c_master` | ⬜  | ⬜        | ⬜          | —               |

## Definition of Done pro Modul

Ein Modul gilt als "fertig" (Häkchen oben), wenn:

1. RTL synthetisierbar ist (kein Simulation-only-Code, keine Latches außer
   gewollt) und in sich abgeschlossen funktioniert.
2. Eine self-checking Testbench nach dem etablierten Muster existiert
   (Synchronisation auf eine beobachtbare Flanke/Event, dann bitweises
   Abtasten und Vergleichen — siehe `tb/tb_uart_tx.sv` als Referenz),
   inklusive Edge Cases (siehe offene Fragen je Modul unten).
3. `just sim <modul>` fehlerfrei durchläuft (`ALL CHECKS PASSED`,
   Exit-Code 0).
4. `just synth <modul>` ohne Fehler durchläuft und der Zellenbericht
   plausibel ist (keine unerwartet riesige Logik).
5. `just lint <modul>` ohne Warnungen durchläuft (oder verbleibende
   Warnungen bewusst mit Begründung akzeptiert sind).
6. Das Modul in der `modules`-Variable im `Justfile` eingetragen ist,
   damit `just ci` und die GitHub-Actions-CI es automatisch mitprüfen.
7. Die Interface-Tabelle in der README für das Modul ergänzt ist.

`just coverage <modul>` ist **kein** Kriterium für "fertig" — der
Recipe braucht lokal einen C++-Compiler (siehe README, Abschnitt
Coverage) und ist aktuell nur in der CI garantiert lauffähig.

## Phase 1 — UART fertigstellen

- [x] `uart_tx`: 8N1-Transmitter mit self-checking Testbench.
- [ ] `uart_rx`: Empfänger-Gegenstück. Offene Fragen, die vor der
      Implementierung zu klären sind:
  - Oversampling-Faktor für die Start-Bit-Erkennung (klassisch 16x) —
    reicht Mid-Point-Sampling wie beim TX-Modell oder soll ein
    Mehrfach-Sampling-Filter gegen Rauschen/Glitches rein?
  - Rahmenfehler-Erkennung (Stop-Bit nicht high → `frame_error`-Flag)?
  - Soll es ein einfaches `rx_valid`-Pulse-Interface analog zu `tx_valid`
    geben, oder zusätzlich ein kleines FIFO?
- [ ] Optional: `uart_top.sv`, das TX und RX zu einem vollständigen
      UART-Controller mit gemeinsamem Taktparameter zusammenführt.

## Phase 2 — SPI Master

- [ ] Recherche: welche der vier SPI-Modi (CPOL/CPHA-Kombinationen)
      werden unterstützt — nur Mode 0 zum Einstieg, oder alle vier
      parametrisierbar?
- [ ] Recherche: ein Chip-Select oder mehrere (Multi-Slave)?
- [ ] `spi_master.sv` mit einfachem Byte-Interface, analog zum
      `tx_valid`/`tx_ready`-Handshake von UART.
- [ ] `tb/tb_spi_master.sv`: Synchronisation auf die SCLK-Flanke,
      bitweises Abtasten von MOSI/MISO — dafür ein Loopback- oder
      simuliertes-Slave-Modell in der Testbench.

## Phase 3 — I2C Master

- [ ] Recherche: Clock Stretching durch den Slave unterstützen?
- [ ] Recherche: Arbitration Lost / Multi-Master von Anfang an
      ausklammern (empfohlen für den Einstieg) oder mitdenken?
- [ ] `i2c_master.sv`: Start/Stop-Bedingung, 7-Bit-Adressierung,
      Byte-Transfer mit ACK/NACK.
- [ ] `tb/tb_i2c_master.sv` mit simuliertem I2C-Slave-Modell (ACK/NACK
      auf SDA erzeugen, Bus-Timing prüfen).
- [ ] Beachten: SDA/SCL sind Open-Drain — im RTL über `tri`/`z`-Zustand
      korrekt modellieren, nicht als normaler Push-Pull-Ausgang.

## Phase 4 — Doku- und Projekt-Politur

- [x] Justfile als einheitlicher Einstiegspunkt (`sim`/`wave`/`synth`/
      `lint`/`coverage`/`ci`), von Terminal, VS-Code-Tasks und CI
      gleichermaßen genutzt.
- [x] GitHub Actions CI (`.github/workflows/ci.yml`): Lint + Simulation
      + Synth-Check als Pflicht-Gate, Coverage-Report als separater Job
      mit Artifact-Upload.
- [x] Zweiter, unabhängiger Linter (Verilator `--lint-only`) zusätzlich
      zu Veribles Editor-Formatierung.
- [x] Line-/Toggle-Coverage via Verilator, CI-verifiziert (lokal unter
      Windows nur mit zusätzlichem C++-Toolchain lauffähig, siehe
      README).
- [ ] README-Interface-Tabellen für SPI und I2C ergänzen (analog zur
      bestehenden UART-Tabelle).
- [ ] Kurze Blockdiagramme (Zustandsautomat oder Timing-Diagramm) pro
      Modul, z.B. als einfache ASCII- oder SVG-Grafik in `docs/`.
- [ ] GTKWave-Screenshots der wichtigsten Signale in die README
      einbinden — macht sich gut für den Lebenslauf/GitHub-Profil.
- [ ] CI-Badge in der README auf den echten `OWNER` umstellen, sobald
      das Repo auf GitHub liegt.

## Phase 5 — Basys 3 Bring-up

Erst starten, wenn Phasen 1–3 stehen und das Board vorhanden ist.

- [ ] Vivado-Projekt anlegen (separates `fpga/` oder `vivado/`-Verzeichnis,
      nicht mit dem simulationsgetriebenen `rtl/`/`tb/`-Fluss vermischen).
- [ ] XDC-Constraints-Datei für Basys 3 (Takt, Taster/Schalter für
      `rst_n`, PMOD- oder USB-UART-Pins je nach Modul).
- [ ] Für UART: Basys 3 hat einen onboard USB-UART-Bridge (FTDI) —
      direkt über den USB-Port am PC testbar, kein externer Adapter nötig.
- [ ] Für SPI/I2C: PMOD-Header nutzen, ggf. Loopback-Testaufbau auf dem
      Board selbst (zwei PMOD-Pins brücken) bevor externe Peripherie
      angeschafft wird.
- [ ] `.gitignore` um Vivado-Projektmüll erweitern (`*.jou`, `*.log`,
      `.Xil/`, `*.cache/`, `*.hw/`, `*.ip_user_files/`, `*.runs/`,
      `*.sim/`), sobald das Vivado-Projekt existiert.

## Stretch Goals (offen, nicht terminiert)

- Zusammenführung von UART/SPI/I2C zu einem einzigen, register-map-
  basierten Controller mit gemeinsamem Bus-Interface (APB oder
  Wishbone-lite) — erst sinnvoll planbar, wenn alle drei Register-/
  Signal-Bedürfnisse bekannt sind.
- Umstieg auf FuseSoC statt des handgepflegten Justfile, sobald die
  Modulanzahl unübersichtlich wird oder mehrere Simulator-/Synthese-
  Targets (z.B. Vivado für Basys 3) sauber verwaltet werden müssen
  (siehe README).
- Verifikation mit cocotb (Python-basiert) statt reinen SV-Testbenches,
  falls für den Lebenslauf ein zweiter, moderner Verifikationsansatz
  gezeigt werden soll.
- FIFOs vor/hinter den Peripherien, um Backpressure realistischer zu
  testen.

## Nicht-Ziele (bewusst ausgeklammert)

- Multi-Master-I2C-Arbitrierung (siehe Phase 3) — deutlich mehr
  Komplexität für wenig zusätzlichen Lerneffekt am Anfang.
- Eigene UVM-Verifikationsumgebung — für den aktuellen Projektumfang
  Overkill; self-checking Testbenches reichen und sind leichter
  nachvollziehbar für Leser des Repos.
