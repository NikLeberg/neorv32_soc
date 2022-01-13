-- =============================================================================
-- File:                    math_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  math_tb
--
-- Description:             Testbench for combined math entity. Implements a
--                          simple unit test to verify that the entities work
--                          correctly together.
--
-- Changes:                 0.1, 2022-01-13, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.datatypes.ALL;

ENTITY math_tb IS
    -- testbench needs no ports
END ENTITY math_tb;

ARCHITECTURE simulation OF math_tb IS
    -- component definition for device under test
    COMPONENT math
        GENERIC (
            num_bits : POSITIVE
        );
        PORT (
            operator : IN operator_type;
            a, b     : IN SIGNED(num_bits - 1 DOWNTO 0);
            y        : OUT SIGNED(num_bits - 1 DOWNTO 0);
            div_zero : OUT STD_LOGIC
        );
    END COMPONENT math;
    -- signals and constants for connecting to the DUT
    CONSTANT c_num_bits : POSITIVE := 8;
    SIGNAL s_operator : operator_type := NOTHING;
    SIGNAL s_a, s_b : SIGNED(c_num_bits - 1 DOWNTO 0) := to_signed(0, c_num_bits);
    SIGNAL s_y : SIGNED(c_num_bits - 1 DOWNTO 0);
    SIGNAL s_div_zero : STD_LOGIC;
    -- test vectors
    TYPE test_vector IS RECORD
        operator : operator_type;
        a, b, y : INTEGER;
        div_zero : STD_LOGIC;
    END RECORD;
    TYPE test_vector_array IS ARRAY (NATURAL RANGE <>) OF test_vector;
    CONSTANT vectors : test_vector_array := (
        -- Test each operation once with the simplest possible expression and
        -- then test again with the b input number set to 0 to check if division
        -- by zero error is only triggered for division.
        test_vector'(NOTHING, 1, 1, 0, '0'), -- nothing
        test_vector'(NOTHING, 1, 0, 0, '0'), -- nothing
        test_vector'(ADD, 1, 1, 2, '0'), -- 1 + 1 = 2
        test_vector'(ADD, 1, 0, 1, '0'), -- 1 + 0 = 1
        test_vector'(SUBTRACT, 1, 1, 0, '0'), -- 1 - 1 = 0
        test_vector'(SUBTRACT, 1, 0, 1, '0'), -- 1 - 0 = 0
        test_vector'(MULTIPLY, 1, 1, 1, '0'), -- 1 * 1 = 1
        test_vector'(MULTIPLY, 1, 0, 0, '0'), -- 1 * 0 = 0
        test_vector'(DIVIDE, 1, 1, 1, '0'), -- 1 / 1 = 1
        test_vector'(DIVIDE, 1, 0, -1, '1'), -- 1 / 0 -> error
        test_vector'(ENTER, 1, 1, 0, '0'), -- nothing
        test_vector'(ENTER, 1, 0, 0, '0'), -- nothing
        test_vector'(CHANGE_SIGN, 1, 1, -1, '0'), -- 1 -> -1
        test_vector'(CHANGE_SIGN, 1, 0, -1, '0') -- 1 -> -1
    );
BEGIN
    -- instantiate the device under test
    dut : math
    GENERIC MAP(
        num_bits => c_num_bits
    )
    PORT MAP(
        operator => s_operator,
        a        => s_a,
        b        => s_b,
        y        => s_y,
        div_zero => s_div_zero
    );

    test : PROCESS IS
    BEGIN
        -- test each value from the test vector
        FOR i IN 0 TO vectors'length - 1 LOOP
            s_operator <= vectors(i).operator;
            s_a <= to_signed(vectors(i).a, c_num_bits);
            s_b <= to_signed(vectors(i).b, c_num_bits);
            WAIT FOR 10 ns;
            ASSERT s_y = to_signed(vectors(i).y, c_num_bits) AND s_div_zero = vectors(i).div_zero
            REPORT "Expected result of testvector " &
                INTEGER'image(i) & " not satisfied."
                SEVERITY failure;
        END LOOP;

        -- report successful test
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
