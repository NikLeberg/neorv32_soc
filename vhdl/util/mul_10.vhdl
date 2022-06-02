-- =============================================================================
-- File:                    mul_10.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  mul_10
--
-- Description:             Multiplies the given input with 10. A multiplication
--                          with a constant can be represented in an addition of
--                          the individual multiples of 2. x*10 = x*8 + x*2. A
--                          multiplication with a power of 2 is just a shift so
--                          this makes for an easy algorithm.
--
-- Changes:                 0.1, 2022-06-02, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY mul_10 IS
    GENERIC (
        N_BITS : POSITIVE := 8 -- bit with of binary in-/output
    );
    PORT (
        x : IN UNSIGNED(N_BITS - 1 DOWNTO 0); -- input
        y : OUT UNSIGNED(N_BITS - 1 DOWNTO 0) -- output = input * 10
    );
END ENTITY mul_10;

ARCHITECTURE no_target_specific OF mul_10 IS
    -- Intermediate results of shifted input value.
    SIGNAL s_x_shift_3, s_x_shift_1 : UNSIGNED(N_BITS - 1 DOWNTO 0);
BEGIN

    -- =========================================================================
    -- Purpose: Constant multiplication x*10 = x*8 + x*2 = x<<3 + x<<1
    -- Type:    combinational
    -- Inputs:  x
    -- Outputs: y
    -- =========================================================================
    s_x_shift_3 <= x(x'HIGH - 3 DOWNTO 0) & "000";
    s_x_shift_1 <= x(x'HIGH - 1 DOWNTO 0) & '0';
    y <= s_x_shift_3 + s_x_shift_1;

END ARCHITECTURE no_target_specific;
