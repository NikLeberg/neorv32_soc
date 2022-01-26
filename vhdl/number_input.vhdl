-- =============================================================================
-- File:                    number_input.vhdl
--
-- Authors:                 Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  number_input
--
-- Description:             Holds / saves the last three entered numbers from
--                          the keypad.
--
-- Changes:                 0.1, 2021-12-10, reusa1
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY number_input IS
    GENERIC (
        -- number of digits
        num_bcd : POSITIVE
    );
    PORT (
        clock   : IN STD_LOGIC;
        n_reset : IN STD_LOGIC;
        number  : IN UNSIGNED(3 DOWNTO 0);
        pressed : IN STD_LOGIC; -- 1 if a new number was pressed

        bcd : OUT STD_LOGIC_VECTOR(num_bcd * 4 DOWNTO 0)
    );
END ENTITY number_input;

ARCHITECTURE no_target_specific OF number_input IS
BEGIN
END ARCHITECTURE no_target_specific;
