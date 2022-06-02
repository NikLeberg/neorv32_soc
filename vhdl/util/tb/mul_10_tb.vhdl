-- =============================================================================
-- File:                    mul_10_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  mul_10_tb
--
-- Description:             Testbench for mul_10 entity. Checks if the constant
--                          multiplication by 10 is correctly calculated.
--
-- Changes:                 0.1, 2022-06-02, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY mul_10_tb IS
    -- Testbench needs no ports.
END ENTITY mul_10_tb;

ARCHITECTURE simulation OF mul_10_tb IS
    -- Component definition for device under test.
    COMPONENT mul_10
        GENERIC (
            N_BITS : POSITIVE
        );
        PORT (
            x : IN UNSIGNED(N_BITS - 1 DOWNTO 0);
            y : OUT UNSIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT mul_10;
    -- Signals for connecting to the DUT.
    CONSTANT c_n_bits : POSITIVE := 8;
    SIGNAL s_x, s_y : UNSIGNED(c_n_bits - 1 DOWNTO 0) := (OTHERS => '0');
BEGIN
    -- Instantiate the device under test.
    dut : mul_10
    GENERIC MAP(
        N_BITS => c_n_bits
    )
    PORT MAP(
        x => s_x,
        y => s_y
    );

    test : PROCESS IS
        -- Procedure that generates stimuli for the given input. Output is
        -- checked if its equal to x * 10.
        PROCEDURE check (CONSTANT x : NATURAL) IS -- x: input value
        BEGIN
            s_x <= to_unsigned(x, c_n_bits);
            WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
            ASSERT to_integer(s_y) = x * 10
            REPORT "Expected y to be " & INTEGER'image(x * 10) & " but got " &
                INTEGER'image(to_integer(s_y)) & "."
                SEVERITY failure;
        END PROCEDURE check;
    BEGIN
        -- Check every possible input x in the N bits value range that, if
        -- multiplied with 10, still fits into the N bits.
        FOR i IN (2 ** c_n_bits - 1) / 10 DOWNTO 0 LOOP
            check(i);
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
