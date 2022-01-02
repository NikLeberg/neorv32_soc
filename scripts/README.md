# scripts

In diesem Ordner sind diverse Tcl-Skripte zur Automatisierung verschiedener Aufgaben abgelegt.

Die `modelsim_*.tcl` Skripte können wie folgt aus dem Ordner `../modelsim` ausgeführt werden: `vsim -c -do ../scripts/<script>.tcl`. Soll zusätzlich die ModelSim GUI gestartet werden, so kann der `-c` Parameter weggelassen werden.

Analog dazu lassen sich die `quartus_*.tcl` Skripte wie folgt aus dem Ordner `../quartus` heraus ausführen: `quartus_sh -t ../scripts/<script>.tcl`.

## files.tcl
Diese Datei ist sehr wichtig. Sie definiert wo die VHDL Dateien gefunden werden können und listet alle Entitäten auf welche von ModelSim und Quartus verwendet werden sollen. Basierend auf ihr werden die Projektdateien für ModelSim und Quartus generiert. ModelSim verwendet die Entitäten (Variable `entities`) und die Testbenches (Variable `testbenches`). Quartus verwendet nur die Entitäten. Wichtig ist die Reihenfolge der Entitäten, denn diese werden von oben nach unten Kompiliert (zumindest für ModelSim). Daher kann eine Entität "oben" in der Liste keine Entität verwenden die "unterhalb" in der Liste steht.

## io_assignment
In diesem Ordner sind die I/O Zuweisungen für das GECKO-Board zu finden. Genaueres zu den benötigten Zuweisungen lässt sich auf der [GECKO-Website](https://gecko-wiki.ti.bfh.ch/gecko4education:start) finden.
