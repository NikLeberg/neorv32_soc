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
USE work.datatypes.ALL;

ENTITY number_input IS
    PORT (
        clock   : IN STD_LOGIC;
        n_reset : IN STD_LOGIC;
        number  : IN UNSIGNED(3 DOWNTO 0);
        pressed : IN STD_LOGIC; -- 1 if a new number was pressed

        bcd : OUT bcd_type -- BCD representation of the last three numbers
    );
END ENTITY number_input;

ARCHITECTURE no_target_specific OF number_input IS
BEGIN
END ARCHITECTURE no_target_specific;
