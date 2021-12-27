# RPN-Rechner in VHDL

Ein (ungewöhnlicher) Taschenrechner. Erstellt als Projekt für das Modul BTE5023 – Elektronische Systeme. Ziel des Projektes ist auf einem [GECKO4-Education](https://gecko-wiki.ti.bfh.ch/gecko4education:start) einen einfachen [reverse Polish notation](https://de.wikipedia.org/wiki/Umgekehrte_polnische_Notation) Rechner zu implementieren. (Siehe [Aufgabenstellung](project-rpn-calculator-de.pdf).)

## Projektablauf
1. [x] Aufgabenstellung analysieren
2. [ ] Projekt aufsetzen
    - [x] GitLab
    - [x] ModelSim
    - [ ] Quartus
3. [ ] Konzept erarbeiten
    - [ ] Blockschaltbild
    - [ ] Zeitplan
    - [ ] Modulschnittstellen
4. [ ] Module implementieren
    - [ ] Implementation
    - [ ] Tests in Simulation
    - [ ] Tests auf Hardware

## Projektstruktur
<!-- mit `tree` generieren -->
```bash
.
├───.vscode             # Optionale Supportdateien um VScode als IDE einzurichten
├───modelsim            # ModelSim Projekt für die Simulation
├───quartus             # Intel Quartus Projekt für FPGA Intel Cyclone IV EP4CE15F23C8
├───scripts
│   ├───io_assignment   # Tcl Skripts der GECKO I/O von gecko-wiki.ti.bfh.ch
│   └───tests
└───vhdl                # VHDL Beschreibungen der rpn Komponenten und deren Testbenches
```

## Synthese und Nutzung
- Für viele Module sind Testbenches definiert. Diese lassen sich mit dem Tcl-Skript `run.do` ausführen resp. simulieren.
```bash
cd modelsim
vsim -c -do ../scripts/tests/run.do
```
- (Simulationsbefehle)
- (Synthesebefehle)
- (Flasherbefehle)
- Nun kann das GECKO-Board mit dem angeschlossenen PmodKYPD bedient werden und funktioniert als funktionstüchtiger RPN-Rechner:
    - Ziffern 0 - 9: Zahleneingabe
    - Taste A: Addieren
    - Taste B: Subtrahieren
    - Taste C: Multiplizieren
    - Taste D: Dividieren
    - Taste E: "Enter" oder verschieben einer Zahl in den Stack
    - Taste F: Vorzeichenwechsel
    - (GECKO)-Button SW6: Power on Reset

## Stand des Projekts
- ToDo

## Lizenz
[MIT](LICENSE) © [N. Leuenberger](mailto:leuen4@bfh.ch), [A. Reusser](mailto:reusa1@bfh.ch).
