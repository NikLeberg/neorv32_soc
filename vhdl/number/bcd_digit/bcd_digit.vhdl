-- =============================================================================
-- File:                    bcd_digit.vhdl
--
-- Authors:                 Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.1
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
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY bcd_digit IS
    PORT (
        clock, n_reset : IN STD_LOGIC;

        up, down : IN STD_LOGIC; -- pulses to count up or down
        enable   : IN STD_LOGIC; -- enable (=1) processing of count pulses

        prev_digit_overflow  : IN STD_LOGIC; -- overflow of previous digit
        next_digit_underflow : IN STD_LOGIC; -- underflow of next digit

        overflow, underflow : OUT STD_LOGIC; -- over- or underflow of this digit

        bcd : OUT STD_LOGIC_VECTOR(3 DOWNTO 0) -- bcd digit
    );
END ENTITY bcd_digit;

ARCHITECTURE no_target_specific OF bcd_digit IS
BEGIN
END ARCHITECTURE no_target_specific;
