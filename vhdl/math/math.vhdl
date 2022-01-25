-- =============================================================================
-- File:                    math.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  math
--
-- Description:             Combines the different mathematic entities and
--                          selects the operation to be performed based on the
--                          operator_type input.
--
-- Changes:                 0.1, 2022-01-13, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.datatypes.ALL;

ENTITY math IS
    GENERIC (
        num_bits : POSITIVE := 8
    );
    PORT (
        -- Operations are perfomed a (operator) b = y.
        operator : IN operator_type;
        a, b     : IN SIGNED(num_bits - 1 DOWNTO 0);
        y        : OUT SIGNED(num_bits - 1 DOWNTO 0);
        -- Division by zero error (b = 0 and operator = DIVIDE)
        div_zero : OUT STD_LOGIC
    );
END ENTITY math;

ARCHITECTURE no_target_specific OF math IS
    -- declare all the mathematical sub entities
    COMPONENT math_add
        GENERIC (
            num_bits : POSITIVE := 8
        );
        PORT (
            a, b : IN SIGNED(num_bits - 1 DOWNTO 0);
            y    : OUT SIGNED(num_bits - 1 DOWNTO 0)
        );
    END COMPONENT math_add;
    COMPONENT math_sub
        GENERIC (
            num_bits : POSITIVE
        );
        PORT (
            a, b : IN SIGNED(num_bits - 1 DOWNTO 0);
            y    : OUT SIGNED(num_bits - 1 DOWNTO 0)
        );
    END COMPONENT math_sub;
    COMPONENT math_mul
        GENERIC (
            num_bits : POSITIVE
        );
        PORT (
            a, b : IN SIGNED(num_bits - 1 DOWNTO 0);
            y    : OUT SIGNED(num_bits - 1 DOWNTO 0)
        );
    END COMPONENT math_mul;
    COMPONENT math_div
        GENERIC (
            num_bits : POSITIVE
        );
        PORT (
            a, b     : IN SIGNED(num_bits - 1 DOWNTO 0);
            y        : OUT SIGNED(num_bits - 1 DOWNTO 0);
            div_zero : OUT STD_LOGIC
        );
    END COMPONENT math_div;
    COMPONENT math_neg
        GENERIC (
            num_bits : POSITIVE := 8
        );
        PORT (
            a : IN SIGNED(num_bits - 1 DOWNTO 0);
            y : OUT SIGNED(num_bits - 1 DOWNTO 0)
        );
    END COMPONENT math_neg;
    -- signals that hold the results of the different mathematical entities
    SIGNAL s_add, s_sub, s_mul, s_div, s_neg : signed(num_bits - 1 DOWNTO 0);
    SIGNAL s_div_zero : STD_LOGIC;
BEGIN
    -- instantiate all the mathematical sub entities
    add_instance : math_add
    GENERIC MAP(
        num_bits => num_bits
    )
    PORT MAP(
        a => a,
        b => b,
        y => s_add
    );
    sub_instance : math_sub
    GENERIC MAP(
        num_bits => num_bits
    )
    PORT MAP(
        a => a,
        b => b,
        y => s_sub
    );
    mul_instance : math_mul
    GENERIC MAP(
        num_bits => num_bits
    )
    PORT MAP(
        a => a,
        b => b,
        y => s_mul
    );
    div_instance : math_div
    GENERIC MAP(
        num_bits => num_bits
    )
    PORT MAP(
        a        => a,
        b        => b,
        y        => s_div,
        div_zero => s_div_zero
    );
    neg_instance : math_neg
    GENERIC MAP(
        num_bits => num_bits
    )
    PORT MAP(
        a => a,
        y => s_neg
    );
    -- =========================================================================
    -- Purpose: Wire the requested result from the mathematic subentities
    -- Type:    combinational
    -- Inputs:  operator, s_add, s_sub, s_mul, s_div, s_neg, s_div_zero
    -- Outputs: y
    -- =========================================================================
    select_operator : PROCESS (operator, s_add, s_sub, s_mul, s_div, s_neg, s_div_zero) IS
    BEGIN
        div_zero <= '0';
        CASE (operator) IS
            WHEN ADD =>
                y <= s_add;
            WHEN SUBTRACT =>
                y <= s_sub;
            WHEN MULTIPLY =>
                y <= s_mul;
            WHEN DIVIDE =>
                y <= s_div;
                div_zero <= s_div_zero;
            WHEN CHANGE_SIGN =>
                y <= s_neg;
            WHEN OTHERS =>
                y <= to_signed(0, num_bits);
        END CASE;
    END PROCESS select_operator;
END ARCHITECTURE no_target_specific;
