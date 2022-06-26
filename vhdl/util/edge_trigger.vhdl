-- =============================================================================
-- File:                    edge_trigger.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  edge_trigger
--
-- Description:             Detects level changes from low to high of the input
--                          signal and emits a high signal for one clock cycle.
--
-- Changes:                 0.1, 2022-06-26, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY edge_trigger IS
    PORT (
        clock, n_reset : IN STD_LOGIC;

        x : IN STD_LOGIC;
        y : OUT STD_LOGIC
    );
END ENTITY edge_trigger;

ARCHITECTURE no_target_specific OF edge_trigger IS
    SIGNAL s_last : STD_LOGIC;
BEGIN

    -- =========================================================================
    -- Purpose: State memory for last input state.
    -- Type:    sequential
    -- Inputs:  clock, x
    -- Outputs: s_last
    -- =========================================================================
    state_memory : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_last <= '0';
            ELSE
                s_last <= x;
            END IF;
        END IF;
    END PROCESS state_memory;

    -- =========================================================================
    -- Purpose: Output logic, detect positive edges.
    -- Type:    combinational
    -- Inputs:  s_last, x
    -- Outputs: y
    -- =========================================================================
    y <= '1' WHEN s_last = '0' AND x = '1' ELSE
        '0';

END ARCHITECTURE no_target_specific;
