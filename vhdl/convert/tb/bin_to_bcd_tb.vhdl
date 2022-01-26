-- =============================================================================
-- File:                    bin_to_bcd_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  bin_to_bcd_tb
--
-- Description:             Test that conversion of binary to bcd representation
--                          is done correctly.
--
-- Changes:                 0.1, 2022-01-26, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY bin_to_bcd_tb IS
    -- testbench needs no ports
END ENTITY bin_to_bcd_tb;

ARCHITECTURE simulation OF bin_to_bcd_tb IS
    -- component definition for device under test
    COMPONENT bin_to_bcd
        GENERIC (
            num_bits : POSITIVE;
            num_bcd  : POSITIVE
        );
        PORT (
            bin : IN SIGNED(num_bits - 1 DOWNTO 0);
            bcd : OUT STD_LOGIC_VECTOR(num_bcd * 4 DOWNTO 0)
        );
    END COMPONENT bin_to_bcd;
    -- signals and constants for connecting to the DUT
    CONSTANT c_num_bits : POSITIVE := 8;
    CONSTANT c_num_bcd : POSITIVE := 3;
    SIGNAL s_bin : SIGNED(c_num_bits - 1 DOWNTO 0);
    SIGNAL s_bcd : STD_LOGIC_VECTOR(c_num_bcd * 4 DOWNTO 0);
BEGIN
    -- instantiate the device under test
    dut : bin_to_bcd
    GENERIC MAP(
        num_bits => c_num_bits,
        num_bcd  => c_num_bcd
    )
    PORT MAP(
        bin => s_bin,
        bcd => s_bcd
    );

    test : PROCESS IS
    BEGIN
        -- test positive values
        FOR i IN 0 TO 2 ** (c_num_bits - 1) - 1 LOOP
            s_bin <= to_signed(i, c_num_bits);
            WAIT FOR 10 ns;
            ASSERT s_bcd(12) = '0' REPORT "Was not positive." SEVERITY failure;
            ASSERT to_integer(UNSIGNED(s_bcd(3 DOWNTO 0))) = i MOD 10
            REPORT "Failed ones in loop " & INTEGER'image(i) & "." SEVERITY failure;
            ASSERT to_integer(UNSIGNED(s_bcd(7 DOWNTO 4))) = (i MOD 100) / 10
            REPORT "Failed tens in loop " & INTEGER'image(i) & "." SEVERITY failure;
            ASSERT to_integer(UNSIGNED(s_bcd(11 DOWNTO 8))) = i / 100
            REPORT "Failed hunderts in loop " & INTEGER'image(i) & "." SEVERITY failure;
        END LOOP;

        -- test negative values
        FOR i IN 1 TO 2 ** (c_num_bits - 1) LOOP
            s_bin <= to_signed(-i, c_num_bits);
            WAIT FOR 10 ns;
            ASSERT s_bcd(12) = '1' REPORT "Was not negative." SEVERITY failure;
            ASSERT to_integer(UNSIGNED(s_bcd(3 DOWNTO 0))) = i MOD 10
            REPORT "Failed ones in loop " & INTEGER'image(i) & "." SEVERITY failure;
            ASSERT to_integer(UNSIGNED(s_bcd(7 DOWNTO 4))) = (i MOD 100) / 10
            REPORT "Failed tens in loop " & INTEGER'image(i) & "." SEVERITY failure;
            ASSERT to_integer(UNSIGNED(s_bcd(11 DOWNTO 8))) = i / 100
            REPORT "Failed hunderts in loop " & INTEGER'image(i) & "." SEVERITY failure;
        END LOOP;

        -- report successful test
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
