-- =============================================================================
-- File:                    offset.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
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
--                          0.2, 2022-05-23, leuen4
--                              Change value ports from UNSIGNED to SIGNED.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY offset IS
    GENERIC (
        N_BITS    : POSITIVE := 10;               -- width of output
        VALUE_MAX : POSITIVE := 2 ** (10 - 1) - 1 -- max positive output value
    );
    PORT (
        x      : IN SIGNED(N_BITS - 1 DOWNTO 0);   -- input value
        offset : IN UNSIGNED(N_BITS - 2 DOWNTO 0); -- offset to add
        y      : OUT SIGNED(N_BITS - 1 DOWNTO 0)   -- output with applied offset
    );
END ENTITY offset;

ARCHITECTURE no_target_specific OF offset IS
    CONSTANT c_max : SIGNED(N_BITS - 1 DOWNTO 0) := to_signed(VALUE_MAX, N_BITS);
    SIGNAL s_x, s_offset, s_addition : SIGNED(N_BITS DOWNTO 0);
BEGIN

    -- =========================================================================
    -- Purpose: Resize inputs to N_BITS + 1.
    -- Type:    combinational
    -- Inputs:  x, offset
    -- Outputs: s_x, s_offset
    -- =========================================================================
    s_x <= x(x'HIGH) & x;
    s_offset <= SIGNED("00" & offset);

    -- =========================================================================
    -- Purpose: Do addition of offset and do a correction if overflow happened.
    -- Type:    combinational
    -- Inputs:  s_x, s_offset, c_max
    -- Outputs: y
    -- =========================================================================
    s_addition <= s_x + s_offset;
    y <= s_addition(N_BITS - 1 DOWNTO 0) WHEN s_addition <= ('0' & c_max) ELSE
        c_max;

END ARCHITECTURE no_target_specific;
