-- =============================================================================
-- File:                    signed_to_unsigned.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  signed_to_unsigned
--
-- Description:             Converts a signed value with N bits into a unsigned
--                          value with M bits for use with a DAC (see dac.vhdl).
--                          N needs to be at least 1 bigger than M. This cant be
--                          done in a simple UNSIGNED cast as the representation
--                          needs to be changed as well. So for y < 0, x = 0.
--                          And for y > 0, x is set to the upper M bits of y
--                          excluding the sign bit.
--
-- Changes:                 0.1, 2022-06-01, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY signed_to_unsigned IS
    GENERIC (
        N_BITS_SIGNED   : POSITIVE := 12; -- width of signed input value
        N_BITS_UNSIGNED : POSITIVE := 10  -- width of unsigned output value
    );
    PORT (
        x : IN SIGNED(N_BITS_SIGNED - 1 DOWNTO 0);     -- signed input value
        y : OUT UNSIGNED(N_BITS_UNSIGNED - 1 DOWNTO 0) -- signed output value
    );
END ENTITY signed_to_unsigned;

ARCHITECTURE no_target_specific OF signed_to_unsigned IS
    CONSTANT c_zero_signed : SIGNED(N_BITS_SIGNED - 1 DOWNTO 0) := (OTHERS => '0');
    CONSTANT c_zero_unsigned : UNSIGNED(N_BITS_UNSIGNED - 1 DOWNTO 0) := (OTHERS => '0');
BEGIN

    -- =========================================================================
    -- Purpose: Convert signed to unsigned value
    -- Type:    combinational
    -- Inputs:  x
    -- Outputs: y
    -- =========================================================================
    y <= c_zero_unsigned WHEN x < c_zero_signed ELSE
        UNSIGNED(x(N_BITS_SIGNED - 2 DOWNTO N_BITS_SIGNED - N_BITS_UNSIGNED - 1));

END ARCHITECTURE no_target_specific;
