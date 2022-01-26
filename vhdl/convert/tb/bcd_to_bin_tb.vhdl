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
-- Changes:                 0.1, 2022-01-26, leuen4
--                              initial version
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
            num_bits : POSITIVE;
            num_bcd  : POSITIVE
        );
        PORT (
            bcd : IN STD_LOGIC_VECTOR(num_bcd * 4 DOWNTO 0);
            bin : OUT SIGNED(num_bits - 1 DOWNTO 0)
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
        num_bits => c_num_bits,
        num_bcd  => c_num_bcd
    )
    PORT MAP(
        bcd => s_bcd,
        bin => s_bin
    );

    test : PROCESS IS
        VARIABLE ones, tens, hunderts : INTEGER;
    BEGIN
        -- test positive values
        FOR i IN 0 TO 2 ** (c_num_bits - 1) - 1 LOOP
            ones := i MOD 10;
            tens := (i MOD 100) / 10;
            hunderts := i / 100;
            s_bcd(12) <= '0';
            s_bcd(11 DOWNTO 8) <= STD_LOGIC_VECTOR(to_unsigned(hunderts, 4));
            s_bcd(7 DOWNTO 4) <= STD_LOGIC_VECTOR(to_unsigned(tens, 4));
            s_bcd(3 DOWNTO 0) <= STD_LOGIC_VECTOR(to_unsigned(ones, 4));
            WAIT FOR 10 ns;
            ASSERT s_bin = to_signed(i, c_num_bits)
            REPORT "Failed with positive number " & INTEGER'image(i) &
                ", returned " & INTEGER'image(to_integer(s_bin)) & "."
                SEVERITY note;
        END LOOP;

        -- test negative values
        FOR i IN 1 TO 2 ** (c_num_bits - 1) LOOP
            ones := i MOD 10;
            tens := (i MOD 100) / 10;
            hunderts := i / 100;
            s_bcd(12) <= '1';
            s_bcd(11 DOWNTO 8) <= STD_LOGIC_VECTOR(to_unsigned(hunderts, 4));
            s_bcd(7 DOWNTO 4) <= STD_LOGIC_VECTOR(to_unsigned(tens, 4));
            s_bcd(3 DOWNTO 0) <= STD_LOGIC_VECTOR(to_unsigned(ones, 4));
            WAIT FOR 10 ns;
            ASSERT s_bin = to_signed(-i, c_num_bits)
            REPORT "Failed with negative number " & INTEGER'image(i) &
                ", returned " & INTEGER'image(to_integer(s_bin)) & "."
                SEVERITY note;
        END LOOP;

        -- report successful test
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
