-- =============================================================================
-- File:                    offset.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  offset
--
-- Description:             Offset for Direct Digital Synthesis. Adds a variable
--                          offset to the input value but ensures that the
--                          output is never bigger than a set maximum. So output
--                          y is x + offset when result would be smaller or
--                          equal to the allowed maximum.
--
-- Changes:                 0.1, 2022-05-08, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY offset IS
    GENERIC (
        N_BITS    : POSITIVE := 10;         -- width of output
        VALUE_MAX : POSITIVE := 2 ** 10 - 1 -- max output value
    );
    PORT (
        x      : IN UNSIGNED(N_BITS - 1 DOWNTO 0); -- input value
        offset : IN UNSIGNED(N_BITS - 1 DOWNTO 0); -- offset to add
        y      : OUT UNSIGNED(N_BITS - 1 DOWNTO 0) -- output with applied offset
    );
END ENTITY offset;

ARCHITECTURE no_target_specific OF offset IS
    CONSTANT c_max : UNSIGNED(N_BITS - 1 DOWNTO 0) := to_unsigned(VALUE_MAX, N_BITS);
BEGIN

    -- =========================================================================
    -- Purpose: Add offset to value but keep it below maximum
    -- Type:    combinational
    -- Inputs:  x, offset, c_max
    -- Outputs: y
    -- =========================================================================
    y <= x + offset WHEN (c_max - x) > offset ELSE
        c_max;

END ARCHITECTURE no_target_specific;
