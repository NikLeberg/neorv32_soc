-- =============================================================================
-- File:                    math_sub.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  math_sub
--
-- Description:             Simply subtracts a number from another.
--
-- Changes:                 0.1, 2022-01-06, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.datatypes.ALL;

ENTITY math_sub IS
    GENERIC (
        num_bits : POSITIVE := 8
    );
    PORT (
        -- a - b = y.
        a, b : IN SIGNED(num_bits - 1 DOWNTO 0);
        y    : OUT SIGNED(num_bits - 1 DOWNTO 0)
    );
END ENTITY math_sub;

ARCHITECTURE no_target_specific OF math_sub IS
BEGIN
    -- =========================================================================
    -- Purpose: Simple subtraction with numeric_std operator
    -- Type:    combinational
    -- Inputs:  a, b
    -- Outputs: y
    -- =========================================================================
    y <= a - b;
END ARCHITECTURE no_target_specific;
