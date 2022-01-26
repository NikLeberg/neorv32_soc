-- =============================================================================
-- File:                    math_neg_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  math_neg_tb
--
-- Description:             Test that negation is done correctly.
--
-- Changes:                 0.1, 2022-01-13, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY math_neg_tb IS
    -- testbench needs no ports
END ENTITY math_neg_tb;

ARCHITECTURE simulation OF math_neg_tb IS
    -- component definition for device under test
    COMPONENT math_neg
        GENERIC (
            num_bits : POSITIVE := 8
        );
        PORT (
            a : IN SIGNED(num_bits - 1 DOWNTO 0);
            y : OUT SIGNED(num_bits - 1 DOWNTO 0)
        );
    END COMPONENT math_neg;
    -- signals and constants for connecting to the DUT
    CONSTANT c_num_bits : POSITIVE := 8;
    SIGNAL s_a : SIGNED(c_num_bits - 1 DOWNTO 0) := to_signed(0, c_num_bits);
    SIGNAL s_y : SIGNED(c_num_bits - 1 DOWNTO 0);
    -- test vectors
    CONSTANT c_max : INTEGER := 2 ** (c_num_bits - 1) - 1; -- INT8_MAX
    CONSTANT c_min : INTEGER := - (c_max + 1); -- INT8_MIN
    TYPE test_vector_array IS ARRAY (NATURAL RANGE <>) OF INTEGER;
    CONSTANT vectors : test_vector_array := (
        -- positive values
        0, 1, 2, 42, c_max,
        -- negative values, note that INT8_MIN can't be represented in INT8
        - 1, -2, -121, (c_min + 1)
    );
BEGIN
    -- instantiate the device under test
    dut : math_neg
    GENERIC MAP(
        num_bits => c_num_bits
    )
    PORT MAP(
        a => s_a,
        y => s_y
    );

    test : PROCESS IS
    BEGIN
        -- test each value from the test vector
        FOR i IN 0 TO vectors'length - 1 LOOP
            s_a <= to_signed(vectors(i), c_num_bits);
            WAIT FOR 10 ns;
            ASSERT s_y = to_signed(-vectors(i), c_num_bits)
            REPORT "Expected: " &
                INTEGER'image(-vectors(i)) & ", but got: " &
                INTEGER'image(to_integer(s_y)) & "."
                SEVERITY failure;
        END LOOP;

        -- report successful test
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
