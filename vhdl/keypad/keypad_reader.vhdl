-- =============================================================================
-- File:                    keypad_reader.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.3
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
--                          0.3, 2022-01-25, leuen4
--                              Fix spurious misreads by synchronizing row input
--                              to the clock. 
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
        COLUMN_1, COLUMN_1_HOLD,
        COLUMN_2, COLUMN_2_HOLD,
        COLUMN_3, COLUMN_3_HOLD,
        COLUMN_4, COLUMN_4_HOLD
    );
    SIGNAL s_rows : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL s_current_state, s_next_state : state_type := COLUMN_1;
BEGIN
    -- =========================================================================
    -- Purpose: Synchronize row input to clock
    -- Type:    sequential
    -- Inputs:  clock, n_reset, rows
    -- Outputs: s_rows
    -- =========================================================================
    row_sync : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_rows <= "1111";
            ELSE
                s_rows <= rows;
            END IF;
        END IF;
    END PROCESS row_sync;

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
                s_current_state <= COLUMN_1;
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
        -- Cyclic activation of each column with an additional hold state. This
        -- is to ensure that the hardware has enough time to settle the logic
        -- levels. At 80 MHz at least 2 clocks are needed.
        CASE (s_current_state) IS
            WHEN COLUMN_1 =>
                s_next_state <= COLUMN_1_HOLD;
            WHEN COLUMN_1_HOLD =>
                s_next_state <= COLUMN_2;
            WHEN COLUMN_2 =>
                s_next_state <= COLUMN_2_HOLD;
            WHEN COLUMN_2_HOLD =>
                s_next_state <= COLUMN_3;
            WHEN COLUMN_3 =>
                s_next_state <= COLUMN_3_HOLD;
            WHEN COLUMN_3_HOLD =>
                s_next_state <= COLUMN_4;
            WHEN COLUMN_4 =>
                s_next_state <= COLUMN_4_HOLD;
            WHEN COLUMN_4_HOLD =>
                s_next_state <= COLUMN_1;
            WHEN OTHERS =>
                s_next_state <= COLUMN_1;
        END CASE;
    END PROCESS nsl;

    -- =========================================================================
    -- Purpose: Output logic for FSM
    -- Type:    combinational
    -- Inputs:  s_current_state, s_rows
    -- Outputs: columns, key, pressed
    -- =========================================================================
    columns <=
        "1110" WHEN s_current_state = COLUMN_1 OR s_current_state = COLUMN_1_HOLD ELSE
        "1101" WHEN s_current_state = COLUMN_2 OR s_current_state = COLUMN_2_HOLD ELSE
        "1011" WHEN s_current_state = COLUMN_3 OR s_current_state = COLUMN_3_HOLD ELSE
        "0111" WHEN s_current_state = COLUMN_4 OR s_current_state = COLUMN_4_HOLD ELSE
        "1111";
    -- Note that s_rows is synchronized on the clock. But on each clock, the
    -- current state has already advanced one column. So in this decoding matrix
    -- it is compared with the next column.
    key <=
        x"1" WHEN s_current_state = COLUMN_2 AND s_rows = "1110" ELSE
        x"4" WHEN s_current_state = COLUMN_2 AND s_rows = "1101" ELSE
        x"7" WHEN s_current_state = COLUMN_2 AND s_rows = "1011" ELSE
        x"0" WHEN s_current_state = COLUMN_2 AND s_rows = "0111" ELSE
        x"2" WHEN s_current_state = COLUMN_3 AND s_rows = "1110" ELSE
        x"5" WHEN s_current_state = COLUMN_3 AND s_rows = "1101" ELSE
        x"8" WHEN s_current_state = COLUMN_3 AND s_rows = "1011" ELSE
        x"F" WHEN s_current_state = COLUMN_3 AND s_rows = "0111" ELSE
        x"3" WHEN s_current_state = COLUMN_4 AND s_rows = "1110" ELSE
        x"6" WHEN s_current_state = COLUMN_4 AND s_rows = "1101" ELSE
        x"9" WHEN s_current_state = COLUMN_4 AND s_rows = "1011" ELSE
        x"E" WHEN s_current_state = COLUMN_4 AND s_rows = "0111" ELSE
        x"A" WHEN s_current_state = COLUMN_1 AND s_rows = "1110" ELSE
        x"B" WHEN s_current_state = COLUMN_1 AND s_rows = "1101" ELSE
        x"C" WHEN s_current_state = COLUMN_1 AND s_rows = "1011" ELSE
        x"D" WHEN s_current_state = COLUMN_1 AND s_rows = "0111" ELSE
        x"0";
    pressed <= '1' WHEN s_rows /= "1111" AND (
        s_current_state = COLUMN_1 OR s_current_state = COLUMN_2 OR
        s_current_state = COLUMN_3 OR s_current_state = COLUMN_4) ELSE
        '0';
END ARCHITECTURE no_target_specific;
