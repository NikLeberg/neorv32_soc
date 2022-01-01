-- =============================================================================
-- File:                    keypad_debounce.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  keypad_debounce
--
-- Description:             Debounces keypresses that keypad_reader detects by
--                          requiring an certain time of no pressed key before a
--                          keypress is detected as such.
--
-- Changes:                 0.1, 2021-12-30, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY keypad_debounce IS
    GENERIC (
        -- Width of the cooldown value. Internally a counter counts from
        -- (2^num_bits) - 1 down to 0. Only after the counter reached 0 new key
        -- presses will be detected. Earlier will be suppressed.
        num_bits : IN POSITIVE := 24
    );
    PORT (
        clock   : IN STD_LOGIC;
        n_reset : IN STD_LOGIC;

        key     : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        pressed : IN STD_LOGIC;

        -- Register that saves the last pressed key. Is only valid after output
        -- "new_pressed" was high once after reset.
        new_key     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        new_pressed : OUT STD_LOGIC
    );
END ENTITY keypad_debounce;

ARCHITECTURE no_target_specific OF keypad_debounce IS
    CONSTANT c_cooldown : UNSIGNED(num_bits - 1 DOWNTO 0) := to_unsigned((2 ** num_bits) - 1, num_bits);
    CONSTANT c_zero : UNSIGNED(num_bits - 1 DOWNTO 0) := to_unsigned(0, num_bits);
    SIGNAL s_current_state : UNSIGNED(num_bits - 1 DOWNTO 0) := c_zero;
    SIGNAL s_next_state : UNSIGNED(num_bits - 1 DOWNTO 0) := c_zero;
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
                s_current_state <= c_cooldown;
            ELSE
                s_current_state <= s_next_state;
            END IF;
        END IF;
    END PROCESS state_memory;

    -- =========================================================================
    -- Purpose: Next state logic for FSM
    -- Type:    combinational
    -- Inputs:  s_current_state, pressed
    -- Outputs: s_next_state
    -- =========================================================================
    nsl : PROCESS (s_current_state, pressed) IS
    BEGIN
        s_next_state <= s_current_state;
        IF (s_current_state = c_zero) THEN
            -- Counter reached a value of 0. We wait for any key press and then
            -- restart the counter.
            IF (pressed = '1') THEN
                s_next_state <= c_cooldown;
            END IF;
        ELSE
            -- Cooldown is still in progress. Count down.
            s_next_state <= s_current_state - 1;
        END IF;
    END PROCESS nsl;

    -- =========================================================================
    -- Purpose: Memory for last pressed key
    -- Type:    sequential
    -- Inputs:  clock, n_reset, s_current_state, pressed
    -- Outputs: s_last_key
    -- =========================================================================
    key_memory : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            -- With the same condition the upper next state logic restarts the
            -- cooldown counter here the value of the currently pressed key is
            -- saved. The generated signal from the keypad_reader entity is only
            -- active for one clock cycle, so we can't depend on the counter
            -- value being c_cooldown as this would be a clock too late.
            IF (s_current_state = c_zero AND pressed = '1') THEN
                s_last_key <= key;
            ELSIF (n_reset = '0') THEN
                s_last_key <= x"0";
            END IF;
        END IF;
    END PROCESS key_memory;

    -- =========================================================================
    -- Purpose: Output logic for FSM
    -- Type:    combinational
    -- Inputs:  s_current_state, s_last_key
    -- Outputs: new_pressed, new_key
    -- =========================================================================
    new_pressed <= '1' WHEN s_current_state = c_cooldown ELSE
        '0';
    new_key <= s_last_key;
END ARCHITECTURE no_target_specific;
