# .vscode

In diesem Ordner sind optionale Supportdateien für den [Visual Studio Code Editor](https://code.visualstudio.com/) von Microsoft zu finden. Mit diesen Dateien lässt sich VSCode als eine fähige IDE verwenden.

## extensions.json
Gibt Vorschläge für Erweiterungen welche im VSCode installiert werden können. Wird der Ordner in VSCode das erste mal geöffnet, sollte eine Meldung unten rechts erscheinen ob man die vorgeschlagenen Erweiterungen installieren möchte. Alternativ lässt sich dies über `Manage > Extensions > Filter > Recommended` nachholen.
Diese Erweiterungen erlauben VSCode VHDL Dateien zu verstehen und mit schönen Farben darzustellen. Mit der Erweiterung `VHDL LS` wird zudem ein Sprachserver installiert der Syntaxfehler erkennt. Dazu muss jedoch zwingend die Datei `vhdl_ls.toml` im Hauptordner des Projekts vorhanden sein.

## settings.json
Richtet die Erweiterungen ein und optimiert einige allgemeine Einstellungen um ein angenehmes Erlebnis mit VSCode zu bescheren. Weiter werden zwei Kommandozeilen Profile eingerichtet um ModelSim oder Quartus direkt als Kommandozeile starten zu können. `Launch Profile` und dann `ModelSim` oder `Quartus`.

## tasks.json
Automatisiert das Arbeiten mit ModelSim und Quartus in dem einige ausführbare Tasks definiert werden. Wurde die `Taskexplorer` Erweiterung installiert, so sind diese Tasks in der `Explorer` Ansicht unten im `Task Explorer` Menü aufgelistet. Ansonsten können sie per `Terminal > Run Task` gestartet werden. Die Tasks setzen voraus, dass die Programme `vsim, quartus_sh` und `quartus_pgm` im Standartpfad (`PATH` Umgebungsvariable) zu finden sind. Diese lässt sich per `Systemsteuerung > System > Erweiterte Systemeinstellungen > Umgebungsvariablen` einrichten.

### Tasks
- **modelsim**
    - **compile**: Kompiliert alle Entitäten (ausser Testbenches) mit ModelSim.
    - **test**: Kompiliert die Testbenches und führt diese aus.
    - **open**: Öffnet die aktuell ausgewählte VHDL-Datei in der ModelSim GUI Simulation.
- **quartus**
    - **project**: Erzeugt die `.qsf` Projektdatei mit den vorgegebenen VHDL-Dateien und I/O Zuweisungen. (Siehe in [../scripts](../scripts/README.md))
    - **compile**: Kompiliert das Projekt und erzeugt das FPGA Bitfile.
    - **flash**: Programmiert den angeschlossenen FPGA Chip (volatil) mit dem Bitfile.
    - **open**: Öffnet das Projekt in Quartus um normal in der GUI Umgebung arbeiten zu können. Achtung: Änderungen an Einstellungen gehen verloren wenn der `project` Task erneut ausgeführt wird! Um bleibende Änderungen vorzunehmen sind diese im [Tcl Script](../scripts/quartus_project.tcl) anzupassen.
- **clean**: Bereinigt die Vielzahl an Dateien die ModelSim und Quartus erzeugen.

## vhdl.code-snippets
Autovervollständigungen für diverse VHDl Konstrukte. Beim tippen von VHDL Syntax werden diese automatisch von VSCode vorgeschlagen. Alternativ mit `Ctrl+Space` verfügbare Vervollständigungen anzeigen lassen.
