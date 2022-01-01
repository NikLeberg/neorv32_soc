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
USE work.datatypes.ALL;

ENTITY keypad_decoder IS
    PORT (
        key : IN STD_LOGIC_VECTOR(3 DOWNTO 0);

        number   : OUT UNSIGNED(3 DOWNTO 0);
        operator : OUT operator_type
    );
END ENTITY keypad_decoder;

ARCHITECTURE no_target_specific OF keypad_decoder IS
BEGIN
    -- =========================================================================
    -- Purpose: Converts key to numerical representation
    -- Type:    combinational
    -- Inputs:  key
    -- Outputs: number
    -- =========================================================================
    number <= to_unsigned(0, 4) WHEN key = x"0" ELSE
        to_unsigned(1, 4) WHEN key = x"1" ELSE
        to_unsigned(2, 4) WHEN key = x"2" ELSE
        to_unsigned(3, 4) WHEN key = x"3" ELSE
        to_unsigned(4, 4) WHEN key = x"4" ELSE
        to_unsigned(5, 4) WHEN key = x"5" ELSE
        to_unsigned(6, 4) WHEN key = x"6" ELSE
        to_unsigned(7, 4) WHEN key = x"7" ELSE
        to_unsigned(8, 4) WHEN key = x"8" ELSE
        to_unsigned(9, 4) WHEN key = x"9" ELSE
        to_unsigned(0, 4);

    -- =========================================================================
    -- Purpose: Converts key to operator representation
    -- Type:    combinational
    -- Inputs:  key
    -- Outputs: operator
    -- =========================================================================
    operator <= ADD WHEN key = x"A" ELSE
        SUBTRACT WHEN key = x"B" ELSE
        MULTIPLY WHEN key = x"C" ELSE
        DIVIDE WHEN key = x"D" ELSE
        ENTER WHEN key = x"E" ELSE
        CHANGE_SIGN WHEN key = x"F" ELSE
        NOTHING;
END ARCHITECTURE no_target_specific;
