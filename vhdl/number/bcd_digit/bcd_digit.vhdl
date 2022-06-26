-- =============================================================================
-- File:                    bcd_digit.vhdl
--
-- Authors:                 Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  bcd_digit
--
-- Description:             Basic building block for managing a BCD value with
--                          over- and underflow signals from other bcd_digit
--                          entities or up- or downcount pulses from an
--                          commanding input like a rotary encoder.
--
-- Changes:                 0.1, 2022-05-04, leuen4
--                              interface definition
--                          0.2, 2022-06-26, reusa1
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY bcd_digit IS
    PORT (
        clock, n_reset : IN STD_LOGIC;

        up, down : IN STD_LOGIC; -- pulses to count up or down
        enable   : IN STD_LOGIC; -- enable (=1) processing of count pulses

        prev_digit_overflow  : IN STD_LOGIC; -- overflow of previous digit
        prev_digit_underflow : IN STD_LOGIC; -- underflow of previous digit

        overflow, underflow : OUT STD_LOGIC; -- over- or underflow of this digit

        bcd : OUT STD_LOGIC_VECTOR(3 DOWNTO 0) -- bcd digit
    );
END ENTITY bcd_digit;

ARCHITECTURE no_target_specific OF bcd_digit IS
    SIGNAL s_current, s_next : UNSIGNED(3 DOWNTO 0);
BEGIN

    -- State memory.
    state_memory : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_current <= (OTHERS => '0');
            ELSE
                s_current <= s_next;
            END IF;
        END IF;
    END PROCESS state_memory;

    -- Next state logic.
    next_state : PROCESS (s_current, enable, up, down, prev_digit_overflow, prev_digit_underflow) IS
    BEGIN
        -- Default to prevent latches and minimize if/else chains.
        s_next <= s_current;
        -- Count up on up pulse or overflow of next lower digit.
        IF ((up = '1' AND enable = '1') OR prev_digit_overflow = '1') THEN
            IF (s_current = x"9") THEN
                s_next <= x"0";
            ELSE
                s_next <= s_current + 1;
            END IF;
        END IF;
        -- Count down on down pulse or underflow of next lower digit.
        IF ((down = '1' AND enable = '1') OR prev_digit_underflow = '1') THEN
            IF (s_current = x"0") THEN
                s_next <= x"9";
            ELSE
                s_next <= s_current - 1;
            END IF;
        END IF;
    END PROCESS;

    -- Output logic.
    bcd <= STD_LOGIC_VECTOR(s_current);
    overflow <= '1' WHEN s_current = x"9" AND ((up = '1' AND enable = '1') OR prev_digit_overflow = '1') ELSE
        '0';
    underflow <= '1' WHEN s_current = x"0" AND ((down = '1' AND enable = '1') OR prev_digit_underflow = '1') ELSE
        '0';

END ARCHITECTURE no_target_specific;
