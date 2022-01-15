-- =============================================================================
-- File:                    keypad_reader.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  keypad_reader
--
-- Description:             Read in the Pmod Keyboard from Digilent over the 8
--                          pin interface of row and column lines. For more,
--                          see: https://digilent.com/reference/pmod/pmodkypd/
--
-- Changes:                 0.1, 2021-12-10, leuen4
--                              initial version
--                          0.2, 2021-12-27, leuen4
--                              work in progress implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY keypad_reader IS
    PORT (
        clock   : IN STD_LOGIC;
        n_reset : IN STD_LOGIC;
        rows    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);

        columns : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        -- hexadecimal value of pressed key, 0 = 0x0, 1 = 0x1, ..., F = 0xF
        key     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        pressed : OUT STD_LOGIC
    );
END ENTITY keypad_reader;

ARCHITECTURE no_target_specific OF keypad_reader IS
    TYPE state_type IS (
        COLUMN_1_SET, COLUMN_1_READ,
        COLUMN_2_SET, COLUMN_2_READ,
        COLUMN_3_SET, COLUMN_3_READ,
        COLUMN_4_SET, COLUMN_4_READ
    );
    SIGNAL s_current_state : state_type := COLUMN_1_SET;
    SIGNAL s_next_state : state_type := COLUMN_1_SET;
BEGIN
    -- =========================================================================
    -- Purpose: State memory with synchronous reset
    -- Type:    sequential
    -- Inputs:  clock, n_reset, s_next_state
    -- Outputs: s_current_state
    -- =========================================================================
    state_memory : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_current_state <= COLUMN_1_SET;
            ELSE
                s_current_state <= s_next_state;
            END IF;
        END IF;
    END PROCESS state_memory;

    -- =========================================================================
    -- Purpose: Next state logic for FSM
    -- Type:    combinational
    -- Inputs:  s_current_state
    -- Outputs: s_next_state
    -- =========================================================================
    nsl : PROCESS (s_current_state) IS
    BEGIN
        -- cyclic activation of each column, first in set and then in read state
        CASE (s_current_state) IS
            WHEN COLUMN_1_SET =>
                s_next_state <= COLUMN_1_READ;
            WHEN COLUMN_1_READ =>
                s_next_state <= COLUMN_2_SET;
            WHEN COLUMN_2_SET =>
                s_next_state <= COLUMN_2_READ;
            WHEN COLUMN_2_READ =>
                s_next_state <= COLUMN_3_SET;
            WHEN COLUMN_3_SET =>
                s_next_state <= COLUMN_3_READ;
            WHEN COLUMN_3_READ =>
                s_next_state <= COLUMN_4_SET;
            WHEN COLUMN_4_SET =>
                s_next_state <= COLUMN_4_READ;
            WHEN COLUMN_4_READ =>
                s_next_state <= COLUMN_1_SET;
            WHEN OTHERS =>
                s_next_state <= COLUMN_1_SET;
        END CASE;
    END PROCESS nsl;

    -- =========================================================================
    -- Purpose: Output logic for FSM
    -- Type:    combinational
    -- Inputs:  s_current_state, rows
    -- Outputs: columns, key, pressed
    -- =========================================================================
    columns <= "1110" WHEN s_current_state = COLUMN_1_SET OR s_current_state = COLUMN_1_READ ELSE
        "1101" WHEN s_current_state = COLUMN_2_SET OR s_current_state = COLUMN_2_READ ELSE
        "1011" WHEN s_current_state = COLUMN_3_SET OR s_current_state = COLUMN_3_READ ELSE
        "0111" WHEN s_current_state = COLUMN_4_SET OR s_current_state = COLUMN_4_READ ELSE
        "1111";
    key <= x"1" WHEN s_current_state = COLUMN_1_READ AND rows = "1110" ELSE
        x"4" WHEN s_current_state = COLUMN_1_READ AND rows = "1101" ELSE
        x"7" WHEN s_current_state = COLUMN_1_READ AND rows = "1011" ELSE
        x"0" WHEN s_current_state = COLUMN_1_READ AND rows = "0111" ELSE
        x"2" WHEN s_current_state = COLUMN_2_READ AND rows = "1110" ELSE
        x"5" WHEN s_current_state = COLUMN_2_READ AND rows = "1101" ELSE
        x"8" WHEN s_current_state = COLUMN_2_READ AND rows = "1011" ELSE
        x"F" WHEN s_current_state = COLUMN_2_READ AND rows = "0111" ELSE
        x"3" WHEN s_current_state = COLUMN_3_READ AND rows = "1110" ELSE
        x"6" WHEN s_current_state = COLUMN_3_READ AND rows = "1101" ELSE
        x"9" WHEN s_current_state = COLUMN_3_READ AND rows = "1011" ELSE
        x"E" WHEN s_current_state = COLUMN_3_READ AND rows = "0111" ELSE
        x"A" WHEN s_current_state = COLUMN_4_READ AND rows = "1110" ELSE
        x"B" WHEN s_current_state = COLUMN_4_READ AND rows = "1101" ELSE
        x"C" WHEN s_current_state = COLUMN_4_READ AND rows = "1011" ELSE
        x"D" WHEN s_current_state = COLUMN_4_READ AND rows = "0111" ELSE
        x"0";
    pressed <= '1' WHEN
        rows /= "1111" AND (
        s_current_state = COLUMN_1_READ OR s_current_state = COLUMN_2_READ OR
        s_current_state = COLUMN_3_READ OR s_current_state = COLUMN_4_READ) ELSE
        '0';
END ARCHITECTURE no_target_specific;
