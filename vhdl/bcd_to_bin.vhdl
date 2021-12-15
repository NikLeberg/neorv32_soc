-- =============================================================================
-- File:                    bcd_to_bin.vhdl
--
-- Authors:                 Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  bcd_to_bin
--
-- Description:             Converts a given number from a bcd to a signed
--                          binary representation.
--
-- Changes:                 0.1, 2021-12-15, reusa1
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY work;
USE work.datatypes.ALL;

ENTITY bcd_to_bin IS
    PORT (
        bcd : IN bcd_type;
        bin : OUT SIGNED(11 DOWNTO 0) -- max range: -999 - +999
    );
END ENTITY bcd_to_bin;

ARCHITECTURE no_target_specific OF bcd_to_bin IS
BEGIN
END ARCHITECTURE no_target_specific;
