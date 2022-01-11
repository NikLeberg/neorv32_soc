-- =============================================================================
-- File:                    bin_to_bcd.vhdl
--
-- Authors:                 Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  bin_to_bcd
--
-- Description:             Converts a given number from a signed binary to a
--                          bcd representation.
--
-- Changes:                 0.1, 2021-12-15, reusa1
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.datatypes.ALL;

ENTITY bin_to_bcd IS
    PORT (
        bin : IN SIGNED(11 DOWNTO 0); -- allowed range: -999 - +999
        bcd : OUT bcd_type
    );
END ENTITY bin_to_bcd;

ARCHITECTURE no_target_specific OF bin_to_bcd IS
BEGIN
END ARCHITECTURE no_target_specific;
