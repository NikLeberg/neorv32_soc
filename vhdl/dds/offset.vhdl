-- =============================================================================
-- File:                    offset.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.3
--
-- Entity:                  offset
--
-- Description:             Offset for Direct Digital Synthesis. Adds a variable
--                          offset to the input value but ensures that the
--                          output is never bigger than a set maximum or smaller
--                          than a set minimum. So output y is x + offset when
--                          result would fit in range [min ... max] or otherwise
--                          would be saturated.
--
-- Changes:                 0.1, 2022-05-08, leuen4
--                              initial implementation
--                          0.2, 2022-05-23, leuen4
--                              Change value ports from UNSIGNED to SIGNED.
--                          0.3, 2022-06-01, leuen4
--                              Make offset SIGNED and allow for neg saturation.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY offset IS
    GENERIC (
        N_BITS    : POSITIVE := 10;                -- width of output
        VALUE_MAX : INTEGER  := 2 ** (10 - 1) - 1; -- max positive output value
        VALUE_MIN : INTEGER  := - 2 ** (10 - 1)    -- min negative output value
    );
    PORT (
        x      : IN SIGNED(N_BITS - 1 DOWNTO 0); -- input value
        offset : IN SIGNED(N_BITS - 1 DOWNTO 0); -- offset to add
        y      : OUT SIGNED(N_BITS - 1 DOWNTO 0) -- output with applied offset
    );
END ENTITY offset;

ARCHITECTURE no_target_specific OF offset IS
    CONSTANT c_max : SIGNED(N_BITS - 1 DOWNTO 0) := to_signed(VALUE_MAX, N_BITS);
    CONSTANT c_min : SIGNED(N_BITS - 1 DOWNTO 0) := to_signed(VALUE_MIN, N_BITS);
    SIGNAL s_x, s_offset, s_addition : SIGNED(N_BITS DOWNTO 0) := (OTHERS => '0');
BEGIN

    -- =========================================================================
    -- Purpose: Resize inputs to N_BITS + 1.
    -- Type:    combinational
    -- Inputs:  x, offset
    -- Outputs: s_x, s_offset
    -- =========================================================================
    s_x <= x(x'HIGH) & x;
    s_offset <= offset(offset'HIGH) & offset;

    -- =========================================================================
    -- Purpose: Do addition of offset and saturate to range [min ... max].
    -- Type:    combinational
    -- Inputs:  s_x, s_offset
    -- Outputs: y
    -- =========================================================================
    add_and_saturate : PROCESS (s_x, s_offset, s_addition) IS
    BEGIN
        s_addition <= s_x + s_offset;
        IF s_addition > c_max(c_max'HIGH) & c_max THEN
            y <= c_max;
        ELSIF s_addition < c_min(c_min'HIGH) & c_min THEN
            y <= c_min;
        ELSE
            y <= s_addition(N_BITS - 1 DOWNTO 0);
        END IF;
    END PROCESS add_and_saturate;

END ARCHITECTURE no_target_specific;
