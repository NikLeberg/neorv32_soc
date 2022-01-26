-- =============================================================================
-- File:                    math_mul.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  math_mul
--
-- Description:             Multiply two numbers together with the combinational
--                          add and shift algorithm. Requires no clock witch
--                          makes it very fast but also expensive in silicon
--                          space. Works also on twos complement representation.
--                          For an throught explanation of the algorythm and the
--                          source of this implementation see:
--                          https://www.cs.utah.edu/~rajeev/cs3810/slides/3810-08.pdf
--                          https://stackoverflow.com/q/53329810/16034014
--                          http://wakerly.org/DDPP/DDPP3_mkt/c05samp3.pdf
--
-- Note:                    The following VHDL description contains parts for a
--                          "wide_output" functionality. But it is commented out
--                          because the sign is not always correct. Most
--                          propable somewhere the handling of the twos
--                          complement sign bit is wrong. Or the algorithm is
--                          just plain wrong for signed multiplication.
--
-- Changes:                 0.1, 2022-01-07, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY math_mul IS
    GENERIC (
        num_bits : POSITIVE := 8
        -- -- The result of a multiplication with N bits can only be represented in
        -- -- 2 * N bits accurately e.g. with no overflow. Setting this to "2"
        -- -- changes the output width to 2 * num_bits. Otherwise with a value of 1
        -- -- it has the same width as the inputs and the upper bits are cut off.
        -- wide_output : POSITIVE := 1
    );
    PORT (
        -- a * b = y.
        a, b : IN SIGNED(num_bits - 1 DOWNTO 0);
        y    : OUT SIGNED(num_bits - 1 DOWNTO 0)
        -- y : OUT SIGNED(wide_output * num_bits - 1 DOWNTO 0)
    );
END ENTITY math_mul;

ARCHITECTURE no_target_specific OF math_mul IS
    TYPE bit_mul_type IS ARRAY (NATURAL RANGE <>) OF SIGNED(num_bits - 1 DOWNTO 0);
    TYPE add_shift_type IS ARRAY (NATURAL RANGE <>) OF SIGNED(num_bits DOWNTO 0);
    SIGNAL s_bit_mul : bit_mul_type(num_bits - 1 DOWNTO 0);
    SIGNAL s_add_shift : add_shift_type(num_bits - 1 DOWNTO 0);
    -- component definition for adder that also exposes the carry
    COMPONENT math_add_carry IS
        GENERIC (
            num_bits : POSITIVE
        );
        PORT (
            a, b : IN SIGNED(num_bits - 1 DOWNTO 0);
            y    : OUT SIGNED(num_bits - 1 DOWNTO 0);
            c    : OUT STD_LOGIC
        );
    END COMPONENT math_add_carry;
BEGIN
    -- =========================================================================
    -- Purpose: Multiply a with each bit of b
    -- Type:    combinational
    -- Inputs:  a, b
    -- Outputs: s_bit_mul
    -- =========================================================================
    bit_mul : FOR i IN num_bits - 1 DOWNTO 0 GENERATE
        -- bitwise multiplication is AND in binary
        s_bit_mul(i) <= a WHEN b(i) = '1' ELSE
        to_signed(0, num_bits);
    END GENERATE;

    -- =========================================================================
    -- Purpose: Add intermediates together, but shifted and with carry
    -- Type:    combinational
    -- Inputs:  s_bit_mul
    -- Outputs: s_add_shift, y
    -- =========================================================================
    add_shift : FOR i IN num_bits - 1 DOWNTO 0 GENERATE
        -- The first bit needs no adder as it would be "added" to 0 and stays
        -- the same exept a bigger size.
        bit_0 : IF i = 0 GENERATE
            s_add_shift(i) <= resize(s_bit_mul(i), num_bits + 1);
        END GENERATE;
        -- The rest of the bits use a adder with carry to add the pre multiplied
        -- values of s_bit_mul shifted together.
        bit_rest : IF i /= 0 GENERATE
            add_carry : math_add_carry
            GENERIC MAP(
                num_bits => num_bits
            )
            PORT MAP(
                a => s_bit_mul(i),
                b => s_add_shift(i - 1)(num_bits DOWNTO 1),
                y => s_add_shift(i)(num_bits - 1 DOWNTO 0),
                c => s_add_shift(i)(num_bits)
            );
        END GENERATE;
        -- The result is combined out of the last bit of each multiply "step"
        -- e.g. the bit that is not used by the next adder step.
        y(i) <= s_add_shift(i)(0);
    END GENERATE;

    -- -- =========================================================================
    -- -- Purpose: Wire the upper bits to the result (if enabled)
    -- -- Type:    combinational
    -- -- Inputs:  s_add_shift (top most immediate result)
    -- -- Outputs: y (upper half of bits)
    -- -- =========================================================================
    -- wide_y : IF wide_output /= 1 GENERATE
    --     y(2 * num_bits - 1 DOWNTO num_bits) <= s_add_shift(num_bits - 1)(num_bits DOWNTO 1);
    -- END GENERATE;

END ARCHITECTURE no_target_specific;
