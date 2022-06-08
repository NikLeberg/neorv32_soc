-- =============================================================================
-- File:                    inc.vhdl
--
-- Authors:                 Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.1
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
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_ARITH.ALL;
USE ieee.std_logic_UNSIGNED.ALL;
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

    next_state : PROCESS (curState, A, B)

    BEGIN
        CASE curState IS
                --detent position
            WHEN idle =>

                IF B = '0' THEN
                    nextState <= R1;
                ELSIF A = '0' THEN
                    nextState <= L1;
                ELSE
                    nextState <= idle;
                END IF;
                -- start of right cycle
                --R1
            WHEN R1 =>

                IF B = '1' THEN
                    nextState <= idle;
                ELSIF A = '0' THEN
                    nextState <= R2;
                ELSE
                    nextState <= R1;
                END IF;

                --R2  					
            WHEN R2 =>

                IF A = '1' THEN
                    nextState <= R1;
                ELSIF B = '1' THEN
                    nextState <= R3;
                ELSE
                    nextState <= R2;
                END IF;

                --R3	
            WHEN R3 =>

                IF B = '0' THEN
                    nextState <= R2;
                ELSIF A = '1' THEN
                    nextState <= puls_pos;
                ELSE
                    nextState <= R3;
                END IF;
            WHEN puls_pos =>
                pos <= '1';
                nextState <= idle;

                -- start of left cycle
                --L1 
            WHEN L1 =>

                IF A = '1' THEN
                    nextState <= idle;
                ELSIF B = '0' THEN
                    nextState <= L2;
                ELSE
                    nextState <= L1;
                END IF;

                --L2	
            WHEN L2 =>

                IF B = '1' THEN
                    nextState <= L1;
                ELSIF A = '1' THEN
                    nextState <= L3;
                ELSE
                    nextState <= L2;
                END IF;

                --L3
            WHEN L3 =>

                IF A = '0' THEN
                    nextState <= L2;
                ELSIF B = '1' THEN
                    nextState <= puls_neg;
                ELSE
                    nextState <= L3;
                END IF;
            WHEN puls_neg =>
                neg <= '1';
                nextState <= idle;
            WHEN OTHERS =>

                nextState <= idle;
        END CASE;
    END PROCESS;

END ARCHITECTURE no_target_specific;
