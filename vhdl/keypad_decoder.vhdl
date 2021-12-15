-- =============================================================================
-- File:                    keypad_decoder.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  keypad_decoder
--
-- Description:             Decodes / splits the given hexadecimal key value
--                          into number and operator.
--
-- Changes:                 0.1, 2021-12-10, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY work;
USE work.datatypes.ALL;

ENTITY keypad_decoder IS
    PORT (
        key      : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        number   : OUT UNSIGNED(3 DOWNTO 0);
        operator : OUT operator_type
    );
END ENTITY keypad_decoder;

ARCHITECTURE no_target_specific OF keypad_decoder IS
BEGIN
END ARCHITECTURE no_target_specific;
