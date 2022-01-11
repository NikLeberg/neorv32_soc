-- =============================================================================
-- File:                    math_add_carry_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  math_add_carry_tb
--
-- Description:             Test that addition with carry is done correctly.
--
-- Changes:                 0.1, 2022-01-11, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.datatypes.ALL;

ENTITY math_add_carry_tb IS
    -- testbench needs no ports
END ENTITY math_add_carry_tb;

ARCHITECTURE simulation OF math_add_carry_tb IS
    -- component definition for device under test
    COMPONENT math_add_carry
        GENERIC (
            num_bits : POSITIVE
        );
        PORT (
            a, b : IN SIGNED(num_bits - 1 DOWNTO 0);
            y    : OUT SIGNED(num_bits - 1 DOWNTO 0);
            c    : OUT STD_LOGIC
        );
    END COMPONENT math_add_carry;
    -- signals and constants for connecting to the DUT
    CONSTANT c_num_bits : POSITIVE := 2;
    SIGNAL s_a, s_b : SIGNED(c_num_bits - 1 DOWNTO 0) := to_signed(0, c_num_bits);
    SIGNAL s_y : SIGNED(c_num_bits - 1 DOWNTO 0);
    SIGNAL s_c : STD_LOGIC;
    -- test vectors
    TYPE test_vector IS RECORD
        a, b, y : INTEGER;
        c : STD_LOGIC;
    END RECORD;
    TYPE test_vector_array IS ARRAY (NATURAL RANGE <>) OF test_vector;
    -- We test the simplest case with only two bits.
    -- This only allows for the values: -2, -1, 0 +1 of which we test every of
    -- the 16 possible combinations.
    CONSTANT vectors : test_vector_array := (
        -- -2 + b
        test_vector'(-2, -2, 0, '1'),
        test_vector'(-2, -1, 1, '1'),
        test_vector'(-2, 0, -2, '1'),
        test_vector'(-2, 1, -1, '1'),
        -- -1 + b
        test_vector'(-1, -2, 1, '1'),
        test_vector'(-1, -1, -2, '1'),
        test_vector'(-1, 0, -1, '1'),
        test_vector'(-1, 1, 0, '0'),
        -- 0 + b
        test_vector'(0, -2, -2, '1'),
        test_vector'(0, -1, -1, '1'),
        test_vector'(0, 0, 0, '0'),
        test_vector'(0, 1, 1, '0'),
        -- 1 + b
        test_vector'(1, -2, -1, '1'),
        test_vector'(1, -1, 0, '0'),
        test_vector'(1, 0, 1, '0'),
        test_vector'(1, 1, -2, '0')
    );
BEGIN
    -- instantiate the device under test
    dut : math_add_carry
    GENERIC MAP(
        num_bits => c_num_bits
    )
    PORT MAP(
        a => s_a,
        b => s_b,
        y => s_y,
        c => s_c
    );

    test : PROCESS IS
    BEGIN
        -- test each value from the test vector
        FOR i IN 0 TO vectors'length - 1 LOOP
            s_a <= to_signed(vectors(i).a, c_num_bits);
            s_b <= to_signed(vectors(i).b, c_num_bits);
            WAIT FOR 10 ns;
            ASSERT s_y = to_signed(vectors(i).y, c_num_bits) AND s_c = vectors(i).c
            REPORT "Testvector " & INTEGER'image(i) & " failed. Got " &
                INTEGER'image(to_integer(s_y)) & " and carry " &
                STD_LOGIC'image(s_c) & "."
                SEVERITY failure;
        END LOOP;

        -- report successful test
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
