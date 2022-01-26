-- =============================================================================
-- File:                    bin_to_bcd.vhdl
--
-- Authors:                 Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  bin_to_bcd
--
-- Description:             Converts a given number from a signed binary to a
--                          bcd representation. This implementation is based on
--                          the double dabble algorithm and modeled after the
--                          Verilog implementation from AmeerAbdelhadi:
--                          https://github.com/AmeerAbdelhadi/Binary-to-BCD-Converter/blob/master/bin2bcd.v
--
-- Changes:                 0.1, 2021-12-15, reusa1
--                              initial version
--                          0.2, 2022-01-26, reusa1
--                              implement double dabble algorith
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY bin_to_bcd IS
    GENERIC (
        num_bits : POSITIVE := 8;
        -- Number with size of num_bits has to fit inside this many bcd digits.
        num_bcd : POSITIVE := 3
    );
    PORT (
        bin : IN SIGNED(num_bits - 1 DOWNTO 0);
        -- Highest bit is 1 if negative.
        -- Rest is a multiple of 4 bits and each represent a bcd digit.
        bcd : OUT STD_LOGIC_VECTOR(num_bcd * 4 DOWNTO 0)
    );
END ENTITY bin_to_bcd;

ARCHITECTURE no_target_specific OF bin_to_bcd IS
BEGIN
    -- =========================================================================
    -- Purpose: Double dabble algorithm
    -- Type:    combinational
    -- Inputs:  bin
    -- Outputs: bcd
    -- =========================================================================
    double_dabble : PROCESS (bin) IS
        VARIABLE s_bin : UNSIGNED(num_bits - 1 DOWNTO 0);
        VARIABLE s_bcd : STD_LOGIC_VECTOR(num_bcd * 4 DOWNTO 0);
        VARIABLE v_digit : UNSIGNED(3 DOWNTO 0);
    BEGIN
        -- Convert given signed binary number to unsigned.
        IF (bin(num_bits - 1) = '0') THEN
            s_bin := unsigned(bin);
        ELSE
            s_bin := unsigned(-bin);
        END IF;
        s_bcd := (OTHERS => '0');

        -- Run the algorithm. Shift [bcd:bin] bits to the left and add 3 if a
        -- bcd digit position is greather than 4.
        FOR i IN 0 TO num_bits - 1 LOOP
            -- Shift [bcd:bin] one to the left.
            s_bcd(num_bcd * 4 - 1 DOWNTO 0) := s_bcd(num_bcd * 4 - 2 DOWNTO 0) & s_bin(num_bits - 1);
            s_bin(num_bits - 1 DOWNTO 0) := s_bin(num_bits - 2 DOWNTO 0) & '0';

            -- Add 3 to the bcd digit if it is bigger than 4.
            FOR j IN 0 TO num_bcd - 1 LOOP
                v_digit := UNSIGNED(s_bcd((j * 4) + 3 DOWNTO (j * 4)));
                IF (i < num_bits - 1 AND v_digit > 4) THEN
                    v_digit := v_digit + 3;
                END IF;
                s_bcd((j * 4) + 3 DOWNTO (j * 4)) := STD_LOGIC_VECTOR(v_digit);
            END LOOP;
        END LOOP;

        -- Restore sign of input number into highest bit of output.
        s_bcd(num_bcd * 4) := bin(num_bits - 1);
        bcd <= s_bcd;
    END PROCESS double_dabble;

END ARCHITECTURE no_target_specific;
