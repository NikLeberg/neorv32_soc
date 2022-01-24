# RPN-Rechner in VHDL

Ein (ungewöhnlicher) Taschenrechner. Erstellt als Projekt für das Modul BTE5023 – Elektronische Systeme. Ziel des Projektes ist auf einem [GECKO4-Education](https://gecko-wiki.ti.bfh.ch/gecko4education:start) einen einfachen [reverse Polish notation](https://de.wikipedia.org/wiki/Umgekehrte_polnische_Notation) Rechner zu implementieren.
Weiteres kann aus der [Aufgabenstellung](project-rpn-calculator-de.pdf) entnommen werden.

## Projektablauf
1. [x] Aufgabenstellung analysieren
2. [x] Projekt aufsetzen
    - [x] GitLab
    - [x] ModelSim
    - [x] Quartus
3. [x] Grobkonzept erarbeiten
    - [ ] Blockschaltbild
    - [ ] Zeitplan
    - [ ] Modulschnittstellen
4. [ ] Module implementieren
    - [x] Keypad - (leuen4)
    - [ ] 7-Seg Ansteuerung
    - [ ] BIN -> BCD, BCD -> BIN Wandler
    - [ ] Zahleneingabe
    - [x] LIFO Stack (leuen4)
    - [ ] Stack Anzeige LED
    - [x] Addierer (leuen4)
    - [x] Subtrahierer (leuen4)
    - [x] Multiplizierer (leuen4)
    - [x] Dividierer (leuen4)
    - [ ] Ablaufsteuerung rpn FSM


## Projektstruktur
```bash
.
├───.vscode     # Optionale Supportdateien um VScode als IDE einzurichten.
├───modelsim    # ModelSim Arbeitsordner, Projektdateien werden mit modelsim_* - Skripts aus dem scripts-Ordner generiert.
├───quartus     # Quartus Arbeitsordner, Projektdateien werden mit quartus_* - Skripts aus dem scripts-Ordner generiert.
├───scripts     # Tcl Skripts um Projektdateien zu generieren.
└───vhdl        # VHDL Quelldateien, beschreiben die benötigten rpn entities.
```
Erweiterte Erläuterungen sind in den jeweiligen `README.md` Dateien der Unterordner gegeben.

## Simulation
Die Simulation der verschiedenen Entitäten / Modulen und ihren Testbenches lässt sich mit folgenden Befehlen / Skripten ausführen. Die Befehle sind im `./modelsim` Unterordner auszuführen.

1. Kompilieren mit ModelSim:
```bash
vsim -c -do ../scripts/modelsim_compile.tcl
```

2. Ausführen der Testbenches:
```bash
vsim -c -do ../scripts/modelsim_test.tcl
```

- (optional) Ansicht der Signalverläufe (öffnet ModelSim GUI):
```bash
vsim -c -do ../scripts/modelsim_open.tcl <testbench_name>
```

## Synthese
Um das Projekt mit Quartus zu synthetisieren sind folgende Befehle einzugeben. Die Befehle sind im `./quartus` Unterordner auszuführen.

1. Generierung der Projektdateien:
```bash
quartus_sh -t ../scripts/quartus_project.tcl
```

2. Synthese:
```bash
quartus_sh -t ../scripts/quartus_compile.tcl
```

3. Volatiles Laden auf das GECKO-Board:
```bash
quartus_pgm -c USB-Blaster --mode jtag --operation='p;rpn.sof'
```

- (optional) Permanentes Laden auf das GECKO-Board:
```bash
quartus_cpf -c ../../scripts/quartus_flash.cof; quartus_pgm ../../scripts/quartus_flash.cdf
```

- (optional) Öffnen der Quartus GUI:
```bash
quartus rpn.qpf
```

## Bedienung
Wurde das GECKO-Board mit dem Bitfile programmiert und das PmodKYPD ist angeschlossen, so kann er als funktionstüchtiger RPN-Rechner verwendet werden. Die Bedienung erfolgt über die Tasten 0 - F:
- **Ziffern 0 - 9**: Zahleneingabe
- **Taste A**: Addieren
- **Taste B**: Subtrahieren
- **Taste C**: Multiplizieren
- **Taste D**: Dividieren
- **Taste E**: "Enter" oder verschieben einer Zahl in den Stack
- **Taste F**: Vorzeichenwechsel

Bis zu zehn Zahlen sind im Stack (die LED-Matrix) in binärer Repräsentation sichtbar. Jede Zeile an LEDs steht für eine Zahl:
| LED11 | LED10 | LED9:LED0 |
|-------|-------|-----------|
| an wenn belegt | an wenn negativ | Zahl in binärer Repräsentation |

Zum Zurücksetzen des Rechners (Power on Reset) kann die **Taste SW6** des GECKOS gedrückt werden.

## Stand des Projekts
- ToDo

## Lizenz
[MIT](LICENSE) © [N. Leuenberger](mailto:leuen4@bfh.ch), [A. Reusser](mailto:reusa1@bfh.ch).
