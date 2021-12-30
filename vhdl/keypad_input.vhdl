-- =============================================================================
-- File:                    keypad_input.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  keypad_input
--
-- Description:             Gets the current key press from the keypad_input
--                          entity and compares it to a previously entered key.
--                          If a new keypress is detected, generate a signal.
--
-- Changes:                 0.1, 2021-12-27, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY keypad_input IS
    PORT (
        clock   : IN STD_LOGIC;
        n_reset : IN STD_LOGIC;

        key     : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        pressed : IN STD_LOGIC;

        new_key     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        new_pressed : OUT STD_LOGIC
    );
END ENTITY keypad_input;

ARCHITECTURE no_target_specific OF keypad_input IS
    CONSTANT c_nbits : POSITIVE := 24;
    CONSTANT c_timeout : UNSIGNED(c_nbits - 1 DOWNTO 0) := to_unsigned((2 ** c_nbits) - 1, c_nbits);
    SIGNAL s_current_state : UNSIGNED(c_nbits - 1 DOWNTO 0) := to_unsigned(0, c_nbits);
    SIGNAL s_next_state : UNSIGNED(c_nbits - 1 DOWNTO 0) := to_unsigned(0, c_nbits);
    SIGNAL s_last_key : STD_LOGIC_VECTOR(3 DOWNTO 0) := x"0";
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
                s_current_state <= to_unsigned(0, c_nbits);
            ELSE
                s_current_state <= s_next_state;
            END IF;
        END IF;
    END PROCESS state_memory;

    -- =========================================================================
    -- Purpose: Next state logic for FSM
    -- Type:    combinational
    -- Inputs:  s_current_state, pressed, key, s_last_key
    -- Outputs: s_next_state
    -- =========================================================================
    nsl : PROCESS (s_current_state, pressed, key, s_last_key) IS
    BEGIN
        s_next_state <= s_current_state;
        IF (s_current_state = to_unsigned(0, c_nbits)) THEN
            -- We are idle and wait for any key press to start.
            IF (pressed = '1') THEN
                s_next_state <= to_unsigned(1, c_nbits);
            END IF;
        ELSIF (s_current_state = c_timeout) THEN
            -- We have reached the timeout, wrap counter around to 0.
            s_next_state <= to_unsigned(0, c_nbits);
        ELSE
            -- Neither idle nor in timeout. We increment the counter if we have
            -- no key press or if the key pressed is the same as the last key.
            -- Otherwise we set the counter to 1.
            IF (pressed = '1' AND key /= s_last_key) THEN
                s_next_state <= to_unsigned(1, c_nbits);
            ELSE
                s_next_state <= s_current_state + 1;
            END IF;
        END IF;
    END PROCESS nsl;

    -- =========================================================================
    -- Purpose: Memory for last pressed key
    -- Type:    sequential
    -- Inputs:  clock, n_reset, s_next_state
    -- Outputs: s_current_state
    -- =========================================================================
    key_memory : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            -- Every time the next state logic determined a next state / counter
            -- value of 1 (which means a new key was detected), we save the
            -- currently pressed key. Reset to 0 on reset signal or timeout.
            IF (n_reset = '0' OR s_current_state = c_timeout) THEN
                s_last_key <= x"0";
            ELSIF (s_next_state = to_unsigned(1, c_nbits)) THEN
                s_last_key <= key;
            END IF;
        END IF;
    END PROCESS key_memory;

    -- =========================================================================
    -- Purpose: Output logic for FSM
    -- Type:    combinational
    -- Inputs:  s_current_state, s_last_key
    -- Outputs: new_pressed, new_key
    -- =========================================================================
    new_pressed <= '1' WHEN s_current_state = to_unsigned(1, c_nbits) ELSE
        '0';
    new_key <= s_last_key;
END ARCHITECTURE no_target_specific;
