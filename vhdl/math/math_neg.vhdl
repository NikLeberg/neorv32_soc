-- =============================================================================
-- File:                    math_neg.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  math_neg
--
-- Description:             Simply negates the given number. Note that the
--                          largest negative value can't be negated into the
--                          same bit size. Ex. for 8 bits: -128 would give 128
--                          which doesn't fit in 8 bits.
--
-- Changes:                 0.1, 2022-01-13, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.datatypes.ALL;

ENTITY math_neg IS
    GENERIC (
        num_bits : POSITIVE := 8
    );
    PORT (
        -- -a = y.
        a : IN SIGNED(num_bits - 1 DOWNTO 0);
        y : OUT SIGNED(num_bits - 1 DOWNTO 0)
    );
END ENTITY math_neg;

ARCHITECTURE no_target_specific OF math_neg IS
BEGIN
    -- =========================================================================
    -- Purpose: Simple negation with the help of numeric_std library
    -- Type:    combinational
    -- Inputs:  a
    -- Outputs: y
    -- =========================================================================
    y <= - a;
END ARCHITECTURE no_target_specific;
