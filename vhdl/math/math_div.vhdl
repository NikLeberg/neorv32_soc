-- =============================================================================
-- File:                    math_div.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  math_div
--
-- Description:             Divide one number into the other with the shift and
--                          subtract algorithm. Requires no clock witch makes it
--                          very fast but also expensive in silicon space. In
--                          contrast to the multiplication algorithm, this can't
--                          handle signed twos complement numbers correctly. To
--                          allow division with negative numbers they are
--                          converted to the sign magnitude representation and
--                          converted back in the end.
--                          For an throught explanation of the algorythm and the
--                          source of this implementation see:
--                          http://www.asic-world.com/digital/arithmetic4.html
--
-- Changes:                 0.1, 2022-01-12, leuen4
--                              initial version
--                          0.2, 2022-01-13, leuen4
--                              Simplify sign conversion by only looking at the
--                              first bit of the twos complement numbers. Fixes
--                              also the issue that 0 was converted into -0.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY math_div IS
    GENERIC (
        num_bits : POSITIVE := 8
    );
    PORT (
        -- a / b = y.
        a, b : IN SIGNED(num_bits - 1 DOWNTO 0);
        y    : OUT SIGNED(num_bits - 1 DOWNTO 0);
        -- 1: division by 0 error; 0: no error
        div_zero : OUT STD_LOGIC
    );
END ENTITY math_div;

ARCHITECTURE no_target_specific OF math_div IS
    -- signals to hold the unsigned magnitude of the signed inputs
    SIGNAL s_a, s_b : UNSIGNED(num_bits - 1 DOWNTO 0);
    -- signals that interconnect the subtraction stages
    TYPE intermediate_type IS ARRAY (NATURAL RANGE <>) OF UNSIGNED(num_bits - 1 DOWNTO 0);
    SIGNAL s_sub_pre, s_sub_post, s_sub_shift : intermediate_type(num_bits - 1 DOWNTO 0);
    SIGNAL s_borrow : STD_LOGIC_VECTOR(num_bits - 1 DOWNTO 0);
    -- component definition for subtracter that also exposes the borrow
    COMPONENT math_sub_borrow IS
        GENERIC (
            num_bits : POSITIVE
        );
        PORT (
            a, b : IN UNSIGNED(num_bits - 1 DOWNTO 0);
            y    : OUT UNSIGNED(num_bits - 1 DOWNTO 0);
            w    : OUT STD_LOGIC
        );
    END COMPONENT math_sub_borrow;
BEGIN
    -- =========================================================================
    -- Purpose: Convert signed numbers to their unsigned absolute values
    -- Type:    combinational
    -- Inputs:  a, b
    -- Outputs: s_a, s_b
    -- =========================================================================
    s_a <= unsigned(a) WHEN a(num_bits - 1) = '0' ELSE
        unsigned(-a);
    s_b <= unsigned(b) WHEN b(num_bits - 1) = '0' ELSE
        unsigned(-b);

    -- =========================================================================
    -- Purpose: Subtract-and-shift algorithm
    -- Type:    combinational
    -- Inputs:  s_a, s_b
    -- Outputs: s_sub_pre, s_sub_post, s_sub_shift, s_borrow
    -- =========================================================================
    sub_shift : FOR i IN num_bits - 1 DOWNTO 0 GENERATE
        -- Input to subtractors is always the current looped bit for the lowest
        -- bit. The rest is filled with 0 for the highest bit (num_bits - 1) or
        -- with the lower (num_bits - 1)'s previous subtract-and-shift result
        -- for the rest.
        s_sub_pre(i)(0) <= s_a(i);
        bit_n : IF i = num_bits - 1 GENERATE
            s_sub_pre(i)(num_bits - 1 DOWNTO 1) <= to_unsigned(0, num_bits - 1);
        END GENERATE;
        bit_rest : IF i /= num_bits - 1 GENERATE
            s_sub_pre(i)(num_bits - 1 DOWNTO 1) <= s_sub_shift(i + 1)(num_bits - 2 DOWNTO 0);
        END GENERATE;
        -- Instantiate the subtractor and subtract the dividend from the
        -- intermediate remainder for each digit.
        sub_borrow : math_sub_borrow
        GENERIC MAP(
            num_bits => num_bits
        )
        PORT MAP(
            a => s_sub_pre(i),
            b => s_b,
            y => s_sub_post(i),
            w => s_borrow(i)
        );
        -- The intermediate result of the division is subtracted as stated in
        -- the upper subtractor instance or, if the value was too large (was
        -- borrowed), then the intermediate result of the previous step is
        -- carried on. Also all borrow bits together form the magnitude of the
        -- result.
        s_sub_shift(i) <= s_sub_post(i) WHEN s_borrow(i) = '0' ELSE
        s_sub_pre(i);
    END GENERATE;

    -- =========================================================================
    -- Purpose: Convert sign magnitude result back to signed
    -- Type:    combinational
    -- Inputs:  s_borrow, a, b
    -- Outputs: y
    -- =========================================================================
    -- The borrow bits of each step hold the negated magnitude of the division.
    -- The sign of the result is the XOR of the signs of the inputs. 
    y <= - signed(NOT s_borrow) WHEN (a(num_bits - 1) = '1') XOR (b(num_bits - 1) = '1') ELSE
        signed(NOT s_borrow);

    -- =========================================================================
    -- Purpose: Generate division by zero error if dividend is zero
    -- Type:    combinational
    -- Inputs:  b
    -- Outputs: div_zero
    -- =========================================================================
    div_zero <= '1' WHEN b = 0 ELSE
        '0';

END ARCHITECTURE no_target_specific;
