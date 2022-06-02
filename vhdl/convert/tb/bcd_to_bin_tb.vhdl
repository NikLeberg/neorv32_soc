-- =============================================================================
-- File:                    bcd_to_bin_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  bcd_to_bin_tb
--
-- Description:             Test that conversion of bcd to binary representation
--                          is done correctly.
--
-- Changes:                 0.1, 2022-06-02, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY bcd_to_bin_tb IS
    -- testbench needs no ports
END ENTITY bcd_to_bin_tb;

ARCHITECTURE simulation OF bcd_to_bin_tb IS
    -- component definition for device under test
    COMPONENT bcd_to_bin
        GENERIC (
            N_BITS : POSITIVE;
            N_BCD  : POSITIVE
        );
        PORT (
            bcd : IN STD_LOGIC_VECTOR(N_BCD * 4 DOWNTO 0);
            bin : OUT SIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT bcd_to_bin;
    -- signals and constants for connecting to the DUT
    CONSTANT c_num_bits : POSITIVE := 8;
    CONSTANT c_num_bcd : POSITIVE := 3;
    SIGNAL s_bcd : STD_LOGIC_VECTOR(c_num_bcd * 4 DOWNTO 0);
    SIGNAL s_bin : SIGNED(c_num_bits - 1 DOWNTO 0);
BEGIN
    -- instantiate the device under test
    dut : bcd_to_bin
    GENERIC MAP(
        N_BITS => c_num_bits,
        N_BCD  => c_num_bcd
    )
    PORT MAP(
        bcd => s_bcd,
        bin => s_bin
    );

    test : PROCESS IS
        VARIABLE ones, tens, hunderts : INTEGER;

        -- Procedure that generates stimuli (bcd value) for the DUT. The
        -- returned binary value will be compared with expected value.
        PROCEDURE check (CONSTANT x : INTEGER) IS -- x: input value
            VARIABLE abs_x, ones, tens, hunderts : INTEGER;
        BEGIN
            -- Calculate individual digits.
            abs_x := ABS(x);
            ones := abs_x MOD 10;
            tens := (abs_x MOD 100) / 10;
            hunderts := abs_x / 100;
            -- Set dut input.
            s_bcd(12) <= '0' WHEN x >= 0 ELSE
            '1';
            s_bcd(11 DOWNTO 8) <= STD_LOGIC_VECTOR(to_unsigned(hunderts, 4));
            s_bcd(7 DOWNTO 4) <= STD_LOGIC_VECTOR(to_unsigned(tens, 4));
            s_bcd(3 DOWNTO 0) <= STD_LOGIC_VECTOR(to_unsigned(ones, 4));
            WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
            -- Check that binary represents the expected value.
            ASSERT s_bin = to_signed(x, c_num_bits)
            REPORT "Failed with number " & INTEGER'image(x) & ", returned " &
                INTEGER'image(to_integer(s_bin)) & "."
                SEVERITY failure;
        END PROCEDURE check;
    BEGIN

        -- Test all values for bcd inputs that can be represented in the given
        -- number of binary bits.
        -- test positive values
        FOR i IN 2 ** (c_num_bits - 1) - 1 DOWNTO -2 ** (c_num_bits - 1) LOOP
            check(i);
        END LOOP;

        -- report successful test
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
