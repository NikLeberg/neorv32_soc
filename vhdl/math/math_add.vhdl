-- =============================================================================
-- File:                    math_add.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  math_add
--
-- Description:             Simply adds two numbers together.
--
-- Changes:                 0.1, 2022-01-06, leuen4
--                              initial version
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
        y    : OUT SIGNED(num_bits - 1 DOWNTO 0);
        -- carry
        c : OUT STD_LOGIC
    );
END ENTITY math_add;

ARCHITECTURE no_target_specific OF math_add IS
    SIGNAL s_y : signed(num_bits DOWNTO 0);
BEGIN
    -- =========================================================================
    -- Purpose: Simple addition with extended variants of the input numbers.
    -- Type:    combinational
    -- Inputs:  a, b
    -- Outputs: s_y
    -- =========================================================================
    -- The given inputs are extended with one additional bit to get a carry
    -- output.
    s_y <= resize(a, num_bits + 1) + resize(b, num_bits + 1);

    -- =========================================================================
    -- Purpose: Set value and carry output
    -- Type:    combinational
    -- Inputs:  s_y
    -- Outputs: y, c
    -- =========================================================================
    y <= s_y(num_bits - 1 DOWNTO 0);
    c <= s_y(num_bits);
END ARCHITECTURE no_target_specific;
