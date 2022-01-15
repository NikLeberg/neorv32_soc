# Keypad Entity

Implementiert die Dekodierung des PMOD Keyboards von [Digilent](https://digilent.com/reference/pmod/pmodkypd/).

## FSMs
Für die [keypad_reader](keypad_reader.vhdl) und [keypad_debounce](keypad_debounce.vhdl) Entitäten wurden FSM's gemäss folgenden Zustandsdiagrammen implementiert. Die eckigen Kästchen stehen für Zustände und die Pfeile für Übergänge. Der initiale Zustand nach dem Reset (active low) ist mit einem gestrichelten Pfeil dargestellt.

Näheres zur Implementation wie z.B. die Ausgangslogik findet sich in der jeweiligen VDHL Datei der Entität.

### keypad_reader
```mermaid
flowchart LR;
    S1[COLUMN_1_SET];
    R1[COLUMN_1_READ];
    S2[COLUMN_2_SET];
    R2[COLUMN_2_READ];
    S3[COLUMN_3_SET];
    R3[COLUMN_3_READ];
    S4[COLUMN_4_SET];
    R4[COLUMN_4_READ];
    r[\" "\] -.->|reset = 0| S1;
    S1 --> R1 --> S2 --> R2 --> S3 --> R3 --> S4 --> R4 --> S1;
```
Es ist wichtig, dass die Spalten für jeweils mehr als ein Takt (hier zwei Takte) aktiv sind. Die physische Tastatur ist mit einem Systemtakt von 80 MHz ansonsten zu langsam im reagieren.

### keypad_debounce
```mermaid
flowchart LR;
    r[\" "\] -.->|reset = 0| 0;
    0 -->|pressed = 1| counter_max --> c[counter_max - 1] --> d[...] --> 2 --> 1 --> 0;
    0 -->|pressed = 0| 0
```
