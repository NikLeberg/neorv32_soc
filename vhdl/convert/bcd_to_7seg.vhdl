-- =============================================================================
-- File:                    add_3.vhdl
--
-- Authors:                 Adrian Reusser <reusa1@bfh.ch>
--
-- Version:                 1
--
-- Entity:                  add_3
--
-- Description:             Adds 3
--
-- Changes:                 
-- =============================================================================
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.datatypes.ALL;

ENTITY decoder IS

   

    PORT (
        bcd     : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        segment : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END ENTITY decoder;

ARCHITECTURE no_target_specific OF decoder IS

BEGIN
    --each value is assigned to its specific 7segment code
    segment <= "11111100" WHEN bcd = x"0" ELSE
        "01100000" WHEN bcd = x"1" ELSE
        "11011010" WHEN bcd = x"2" ELSE
        "11110000" WHEN bcd = x"3" ELSE
        "01100110" WHEN bcd = x"4" ELSE
        "10110110" WHEN bcd = x"5" ELSE
        "10111100" WHEN bcd = x"6" ELSE
        "11100000" WHEN bcd = x"7" ELSE
        "11111110" WHEN bcd = x"8" ELSE
        "11110100" WHEN bcd = x"9" ELSE
        "00000000";

END ARCHITECTURE no_target_specific;
