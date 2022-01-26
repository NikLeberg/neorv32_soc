-- =============================================================================
-- File:                    math_div_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  math_div_tb
--
-- Description:             Test that division is done correctly.
--
-- Changes:                 0.1, 2022-01-12, leuen4
--                              initial version
--                          0.2, 2022-01-13, leuen4
--                              fix expected result with division by zero error
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY math_div_tb IS
    -- testbench needs no ports
END ENTITY math_div_tb;

ARCHITECTURE simulation OF math_div_tb IS
    -- component definition for device under test
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
    -- signals and constants for connecting to the DUT
    CONSTANT c_num_bits : POSITIVE := 8;
    SIGNAL s_a, s_b : SIGNED(c_num_bits - 1 DOWNTO 0) := to_signed(0, c_num_bits);
    SIGNAL s_y : SIGNED(c_num_bits - 1 DOWNTO 0);
    SIGNAL s_div_zero : STD_LOGIC;
    -- test vectors
    CONSTANT c_max : INTEGER := 2 ** (c_num_bits - 1) - 1; -- INT8_MAX
    CONSTANT c_min : INTEGER := - (c_max + 1); -- INT8_MIN
    TYPE test_vector IS RECORD
        a, b, y : INTEGER;
        div_zero : STD_LOGIC;
    END RECORD;
    TYPE test_vector_array IS ARRAY (NATURAL RANGE <>) OF test_vector;
    CONSTANT vectors : test_vector_array := (
        -- positive numbers
        test_vector'(1, 1, 1, '0'), -- 1 / 1 = 1
        test_vector'(32, 2, 16, '0'), -- 32 / 2 = 16
        test_vector'(25, 1, 25, '0'), -- 25 / 1 = 25
        test_vector'(25, 5, 5, '0'), -- 25 / 5 = 5
        test_vector'(33, 3, 11, '0'), -- 33 / 3 = 11
        test_vector'(34, 3, 11, '0'), -- 34 / 3 = 11
        test_vector'(35, 3, 11, '0'), -- 35 / 3 = 11
        test_vector'(59, 105, 0, '0'), -- 59 / 105 = 0
        test_vector'(c_max, c_max, 1, '0'), -- INT8_MAX / INT8_MAX = 1
        test_vector'(c_max, 1, c_max, '0'), -- INT8_MAX / 1 = INT8_MAX
        -- negative numbers
        test_vector'(-1, 1, -1, '0'), -- (-1) / 1 = -1
        test_vector'(-1, -1, 1, '0'), -- (-1) / (-1) = 1
        test_vector'(-12, 2, -6, '0'), -- (-12) / 2 = -6
        test_vector'(125, -5, -25, '0'), -- 125 / (-5) = -25
        test_vector'(c_min, c_min, 1, '0'), -- INT8_MIN / INT8_MIN = 1
        test_vector'(c_min, 1, c_min, '0'), -- INT8_MIN / 1 = INT8_MIN
        -- division by zero
        test_vector'(0, 0, -1, '1'), -- 0 / 0 -> error
        test_vector'(1, 0, -1, '1'), -- 1 / 0 -> error
        test_vector'(c_max, 0, -1, '1'), -- INT8_MAX / 0 -> error
        test_vector'(c_min, 0, 1, '1') -- INT8_MIN / 0 -> error
    );
BEGIN
    -- instantiate the device under test
    dut : math_div
    GENERIC MAP(
        num_bits => c_num_bits
    )
    PORT MAP(
        a        => s_a,
        b        => s_b,
        y        => s_y,
        div_zero => s_div_zero
    );

    test : PROCESS IS
    BEGIN
        -- test each value from the test vector
        FOR i IN 0 TO vectors'length - 1 LOOP
            s_a <= to_signed(vectors(i).a, c_num_bits);
            s_b <= to_signed(vectors(i).b, c_num_bits);
            WAIT FOR 10 ns;
            ASSERT s_y = to_signed(vectors(i).y, c_num_bits) AND
            s_div_zero = vectors(i).div_zero
            REPORT "Expected: " &
                INTEGER'image(vectors(i).a) & " / " &
                INTEGER'image(vectors(i).b) & " = " &
                INTEGER'image(vectors(i).y) & " err " &
                STD_LOGIC'image(vectors(i).div_zero) & ", but got: " &
                INTEGER'image(to_integer(s_y)) & " err " &
                STD_LOGIC'image(s_div_zero) & "."
                SEVERITY failure;
        END LOOP;

        -- report successful test
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
