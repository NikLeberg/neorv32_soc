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
        N_BITS : POSITIVE := 8;
        -- Number with size of N_BITS has to fit inside this many bcd digits.
        N_BCD : POSITIVE := 3
    );
    PORT (
        bin : IN SIGNED(N_BITS - 1 DOWNTO 0);
        -- MSB is 1 if negative.
        -- Rest is a multiple of 4 bits and each represent a bcd digit.
        bcd : OUT STD_LOGIC_VECTOR(N_BCD * 4 DOWNTO 0)
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
        VARIABLE v_bin : UNSIGNED(N_BITS - 1 DOWNTO 0);
        VARIABLE v_bcd : STD_LOGIC_VECTOR(N_BCD * 4 DOWNTO 0);
        VARIABLE v_digit : UNSIGNED(3 DOWNTO 0);
    BEGIN
        -- Convert given signed binary number to unsigned.
        IF (bin(N_BITS - 1) = '0') THEN
            v_bin := unsigned(bin);
        ELSE
            v_bin := unsigned(-bin);
        END IF;
        v_bcd := (OTHERS => '0');

        -- Run the algorithm. Shift [bcd:bin] bits to the left and add 3 if a
        -- bcd digit position is greather than 4.
        FOR i IN 0 TO N_BITS - 1 LOOP
            -- Shift [bcd:bin] one to the left.
            v_bcd(N_BCD * 4 - 1 DOWNTO 0) := v_bcd(N_BCD * 4 - 2 DOWNTO 0) & v_bin(N_BITS - 1);
            v_bin(N_BITS - 1 DOWNTO 0) := v_bin(N_BITS - 2 DOWNTO 0) & '0';

            -- Add 3 to the bcd digit if it is bigger than 4.
            FOR j IN 0 TO N_BCD - 1 LOOP
                v_digit := UNSIGNED(v_bcd((j * 4) + 3 DOWNTO (j * 4)));
                IF (i < N_BITS - 1 AND v_digit > 4) THEN
                    v_digit := v_digit + 3;
                END IF;
                v_bcd((j * 4) + 3 DOWNTO (j * 4)) := STD_LOGIC_VECTOR(v_digit);
            END LOOP;
        END LOOP;

        -- Restore sign of input number into highest bit of output.
        v_bcd(N_BCD * 4) := bin(N_BITS - 1);
        bcd <= v_bcd;
    END PROCESS double_dabble;

END ARCHITECTURE no_target_specific;
