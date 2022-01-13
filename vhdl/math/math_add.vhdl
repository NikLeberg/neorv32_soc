-- =============================================================================
-- File:                    math_add.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  math_add
--
-- Description:             Simply adds two numbers together.
--
-- Changes:                 0.1, 2022-01-06, leuen4
--                              initial version
--                          0.2, 2022-01-13, leuen4
--                              remove carry generation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.datatypes.ALL;

ENTITY math_add IS
    GENERIC (
        num_bits : POSITIVE := 8
    );
    PORT (
        -- a + b = y.
        a, b : IN SIGNED(num_bits - 1 DOWNTO 0);
        y    : OUT SIGNED(num_bits - 1 DOWNTO 0)
    );
END ENTITY math_add;

ARCHITECTURE no_target_specific OF math_add IS
BEGIN
    -- =========================================================================
    -- Purpose: Simple addition with the help of numeric_std library
    -- Type:    combinational
    -- Inputs:  a, b
    -- Outputs: y
    -- ========================================================================
    y <= a + b;
END ARCHITECTURE no_target_specific;
