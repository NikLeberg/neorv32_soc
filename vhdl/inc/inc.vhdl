-- =============================================================================
-- File:                    inc.vhdl
--
-- Authors:                 Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.3
--
-- Entity:                  inc
--
-- Description:             Detects the direction in which the encoder shaft of
--                          the Digilent PmodENC is turned. Input signals are
--                          expected to be already free of hazards and
--                          debounced. Output pulses are active for one clock
--                          cycle. Hardware reference:
--                          https://digilent.com/reference/pmod/pmodenc/
--
-- Changes:                 0.1, 2022-04-28, leuen4
--                              interface definition
--                          0.2, 2022-06-07, reusa1
--                              initial implementation
--                          0.3, 2022-06-08, leuen4
--                              add state memory
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY inc IS
    PORT (
        clock, n_reset : IN STD_LOGIC;

        a   : IN STD_LOGIC;  -- signal of button A of the encoder shaft
        b   : IN STD_LOGIC;  -- signal of button B of the encoder shaft
        pos : OUT STD_LOGIC; -- pulse on positive CW rotation
        neg : OUT STD_LOGIC  -- pulse on negative CCW rotation
    );
END ENTITY inc;

ARCHITECTURE no_target_specific OF inc IS
    TYPE stateType IS (idle, R1, R2, R3, L1, L2, L3, puls_pos, puls_neg);
    SIGNAL curState, nextState : stateType;
BEGIN

    -- State memory.
    state_memory : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                curState <= idle;
            ELSE
                curState <= nextState;
            END IF;
        END IF;
    END PROCESS state_memory;

    -- Next state logic.
    next_state : PROCESS (curState, A, B) IS
    BEGIN
        -- Default to prevent latches and minimize if/else chains.
        nextState <= curState;

        CASE curState IS
            WHEN idle => -- detent position

                IF A = '0' AND B = '1' THEN
                    nextState <= R1;
                ELSIF A = '1' AND B = '0' THEN
                    nextState <= L1;
                END IF;

            WHEN R1 => -- start of right cycle

                IF A = '0' AND B = '0' THEN
                    nextState <= R2;
                ELSIF A = '1' THEN
                    nextState <= idle;
                END IF;

            WHEN R2 => -- R2

                IF A = '1' AND B = '0' THEN
                    nextState <= R3;
                ELSIF B = '1' THEN
                    nextState <= idle;
                END IF;

            WHEN R3 => --R3

                IF A = '1' AND B = '1' THEN
                    nextState <= puls_pos;
                ELSIF A = '0' THEN
                    nextState <= idle;
                END IF;

            WHEN puls_pos =>

                nextState <= idle;

            WHEN L1 => -- start of left cycle

                IF A = '0' AND B = '0' THEN
                    nextState <= L2;
                ELSIF B = '1' THEN
                    nextState <= idle;
                END IF;

            WHEN L2 => -- L2

                IF A = '0' AND B = '1' THEN
                    nextState <= L3;
                ELSIF A = '1' THEN
                    nextState <= idle;
                END IF;

            WHEN L3 => -- L3

                IF A = '1' AND B = '1' THEN
                    nextState <= puls_neg;
                ELSIF B = '0' THEN
                    nextState <= idle;
                END IF;

            WHEN puls_neg =>

                nextState <= idle;

            WHEN OTHERS =>

                nextState <= idle;

        END CASE;
    END PROCESS;

    -- Output logic.
    pos <= '1' WHEN curState = puls_pos ELSE
        '0';
    neg <= '1' WHEN curState = puls_neg ELSE
        '0';

END ARCHITECTURE no_target_specific;
