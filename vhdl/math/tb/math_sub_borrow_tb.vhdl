-- =============================================================================
-- File:                    math_sub_borrow_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  math_sub_borrow_tb
--
-- Description:             Test that subtraction with borrow is done correctly.
--
-- Changes:                 0.1, 2022-01-11, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.datatypes.ALL;

ENTITY math_sub_borrow_tb IS
    -- testbench needs no ports
END ENTITY math_sub_borrow_tb;

ARCHITECTURE simulation OF math_sub_borrow_tb IS
    -- component definition for device under test
    COMPONENT math_sub_borrow
        GENERIC (
            num_bits : POSITIVE
        );
        PORT (
            a, b : IN UNSIGNED(num_bits - 1 DOWNTO 0);
            y    : OUT UNSIGNED(num_bits - 1 DOWNTO 0);
            w    : OUT STD_LOGIC
        );
    END COMPONENT math_sub_borrow;
    -- signals and constants for connecting to the DUT
    CONSTANT c_num_bits : POSITIVE := 2;
    SIGNAL s_a, s_b : UNSIGNED(c_num_bits - 1 DOWNTO 0) := to_unsigned(0, c_num_bits);
    SIGNAL s_y : UNSIGNED(c_num_bits - 1 DOWNTO 0);
    SIGNAL s_w : STD_LOGIC;
    -- test vectors
    TYPE test_vector IS RECORD
        a, b, y : INTEGER;
        w : STD_LOGIC;
    END RECORD;
    TYPE test_vector_array IS ARRAY (NATURAL RANGE <>) OF test_vector;
    -- We test the simplest case with only two bits.
    -- This only allows for the values: 0, 1, 2 and 3 of which we test every of
    -- the 16 possible combinations.
    CONSTANT vectors : test_vector_array := (
        -- 3 - b
        test_vector'(3, 0, 3, '0'),
        test_vector'(3, 1, 2, '0'),
        test_vector'(3, 2, 1, '0'),
        test_vector'(3, 3, 0, '0'),
        -- 2 - b
        test_vector'(2, 0, 2, '0'),
        test_vector'(2, 1, 1, '0'),
        test_vector'(2, 2, 0, '0'),
        test_vector'(2, 3, 3, '1'),
        -- 1 - b
        test_vector'(1, 0, 1, '0'),
        test_vector'(1, 1, 0, '0'),
        test_vector'(1, 2, 3, '1'),
        test_vector'(1, 3, 2, '1'),
        -- 0 - b
        test_vector'(0, 0, 0, '0'),
        test_vector'(0, 1, 3, '1'),
        test_vector'(0, 2, 2, '1'),
        test_vector'(0, 3, 1, '1')
    );
BEGIN
    -- instantiate the device under test
    dut : math_sub_borrow
    GENERIC MAP(
        num_bits => c_num_bits
    )
    PORT MAP(
        a => s_a,
        b => s_b,
        y => s_y,
        w => s_w
    );

    test : PROCESS IS
    BEGIN
        -- test each value from the test vector
        FOR i IN 0 TO vectors'length - 1 LOOP
            s_a <= to_unsigned(vectors(i).a, c_num_bits);
            s_b <= to_unsigned(vectors(i).b, c_num_bits);
            WAIT FOR 10 ns;
            ASSERT s_y = to_unsigned(vectors(i).y, c_num_bits) AND s_w = vectors(i).w
            REPORT "Testvector " & INTEGER'image(i) & " failed. Got " &
                INTEGER'image(to_integer(s_y)) & " and borrow " &
                STD_LOGIC'image(s_w) & "."
                SEVERITY failure;
        END LOOP;

        -- report successful test
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
