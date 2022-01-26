-- =============================================================================
-- File:                    math_sub_borrow.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  math_sub_borrow
--
-- Description:             Simply subtracts a number from another. Additionaly
--                          to the math_sub entity it also generates a borrow
--                          output.
--
-- Changes:                 0.1, 2022-01-11, leuen4
--                              initial version
--                          0.2, 2022-01-12, leuen4
--                              Change signed to unsigned type because math_div
--                              entity that uses this entity internally uses
--                              sign magnitude represantation isntead of twos
--                              complement.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY math_sub_borrow IS
    GENERIC (
        num_bits : POSITIVE
    );
    PORT (
        -- a - b = y.
        a, b : IN UNSIGNED(num_bits - 1 DOWNTO 0);
        y    : OUT UNSIGNED(num_bits - 1 DOWNTO 0);
        -- borrow
        w : OUT STD_LOGIC
    );
END ENTITY math_sub_borrow;

ARCHITECTURE no_target_specific OF math_sub_borrow IS
    SIGNAL s_y : UNSIGNED(num_bits DOWNTO 0);
BEGIN
    -- =========================================================================
    -- Purpose: Simple subtraction with extended variants of the input numbers.
    -- Type:    combinational
    -- Inputs:  a, b
    -- Outputs: s_y
    -- =========================================================================
    -- The given inputs are extended with one additional bit to get a borrow
    -- output.
    s_y <= resize(a, num_bits + 1) - resize(b, num_bits + 1);

    -- =========================================================================
    -- Purpose: Set value and borrow output
    -- Type:    combinational
    -- Inputs:  s_y
    -- Outputs: y, w
    -- =========================================================================
    y <= s_y(num_bits - 1 DOWNTO 0);
    w <= s_y(num_bits);
END ARCHITECTURE no_target_specific;
