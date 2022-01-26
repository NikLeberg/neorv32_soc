# vhdl

In diesem Ordner sind die benötigten VHDL Beschreibungen zu finden.

## Ordnerstruktur
Die VHDL Dateien sind entsprechend ihrer Funktion in Unterordner gegliedert.
Folgend ist ein kurzer Überblick gegeben wie diese Unterordner strukturiert sind:

```bash
.
│   rpn.vhdl        # Top-Level Entität "rpn"
│   datatypes.vhdl  # Globale Datentypen
│   *.vhdl          # diverse Support Entitäten
│
└───<entity_name>           # Ein "Modul" als Kombination verschiedener Entitäten.
    │   <entity_name>.vhdl  # Haupt-Entität welche von anderen Modulen verwendet werden kann.
    │   *.vhdl              # weitere (private) Entitäten
    │
    └───tb                  # Testbench(es) für die Entität(en)
```

Wichtig ist, dass jede Entität welche verwendet wird, in der Skriptdatei [files.tcl](../scripts/files.tcl) angegeben wird. Ansonsten wird diese nicht in das ModelSim oder Quartus Projekt eingebunden.

## rpn FSM

```mermaid
flowchart TB;
    %% initial state
    r[\" "\] -.->|reset = 0| INPUT_NUMBER;

    %% number input reading
    INPUT_NUMBER -->|operator = NOTHING| INPUT_NUMBER;

    %% do the math
    INPUT_NUMBER -->|operator /= NOTHING| PUSH_NEW_TO_STACK;
    PUSH_NEW_TO_STACK -->|operator /= ENTER| DO_MATH;
    PUSH_NEW_TO_STACK -->|operator = ENTER| CLEAR_OP;
    

    %% only one operand was needed
    DO_MATH -->|operator = CHANGE_SIGN| POP_A_FROM_STACK;

    %% two operands were needed
    DO_MATH -->|operator /= CHANGE_SIGN| POP_B_FROM_STACK;
    POP_B_FROM_STACK --> POP_A_FROM_STACK;
    POP_A_FROM_STACK --> PUSH_TO_STACK;
    PUSH_TO_STACK --> CLEAR_OP;
    CLEAR_OP-->INPUT_NUMBER;

    %% no operands needed
    %%INPUT_NUMBER -->|operator = ENTER| PUSH_RESULT_TO_STACK

```
