-- =============================================================================
-- File:                    bcd_to_bin.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  bcd_to_bin
--
-- Description:             Converts a given number from a bcd to a signed
--                          binary representation. The reverse of the double
--                          dabble algorithm could be used for that. But here
--                          the digits are multiplied one by one with a constant
--                          x10 multiplier.
--
-- Changes:                 0.1, 2022-06-02, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY bcd_to_bin IS
    GENERIC (
        N_BCD : POSITIVE := 3;
        -- Number with N_BCD digits has to fit inside binary number of N_BITS.
        N_BITS : POSITIVE := 8
    );
    PORT (
        -- MSB is 1 if negative.
        -- Rest is a multiple of 4 bits and each represent a bcd digit.
        bcd : IN STD_LOGIC_VECTOR(N_BCD * 4 DOWNTO 0);
        bin : OUT SIGNED(N_BITS - 1 DOWNTO 0)
    );
END ENTITY bcd_to_bin;

ARCHITECTURE no_target_specific OF bcd_to_bin IS
    -- Define component mul_10.
    COMPONENT mul_10 IS
        GENERIC (
            N_BITS : POSITIVE := 8 -- bit with of binary in-/output
        );
        PORT (
            x : IN UNSIGNED(N_BITS - 1 DOWNTO 0); -- input
            y : OUT UNSIGNED(N_BITS - 1 DOWNTO 0) -- output = input * 10
        );
    END COMPONENT mul_10;

    TYPE intermediate_type IS ARRAY (NATURAL RANGE <>) OF UNSIGNED(N_BITS - 1 DOWNTO 0);
    SIGNAL s_digits, s_mul_out, s_add_out : intermediate_type(N_BCD - 1 DOWNTO 0);

BEGIN

    -- =========================================================================
    -- Purpose: Split bcd input into digits and extend them to N bits.
    -- Type:    combinational
    -- Inputs:  bcd
    -- Outputs: s_digits
    -- =========================================================================
    bcd_digits : FOR i IN N_BCD - 1 DOWNTO 0 GENERATE
        s_digits(i) <= resize(UNSIGNED(bcd((i * 4) + 3 DOWNTO (i * 4))), N_BITS);
    END GENERATE;

    -- =========================================================================
    -- Purpose: Multiply ever digit by 10 with mul_10 entity.
    -- Type:    combinational
    -- Inputs:  s_digits, s_add_out
    -- Outputs: s_mul_out
    -- =========================================================================
    mul_by_10 : FOR i IN N_BCD - 1 DOWNTO 1 GENERATE
        -- First x10 entity gets value from highest digit directly.
        msb_digit : IF i = N_BCD - 1 GENERATE
            mul_10_msb : mul_10
            GENERIC MAP(
                N_BITS => N_BITS
            )
            PORT MAP(
                x => s_digits(i),
                y => s_mul_out(i)
            );
        END GENERATE;
        -- Rest of them get value from previous x10 and after adding new digit.
        rest_digits : IF i /= N_BCD - 1 GENERATE
            mul_10_rest : mul_10
            GENERIC MAP(
                N_BITS => N_BITS
            )
            PORT MAP(
                x => s_add_out(i),
                y => s_mul_out(i)
            );
        END GENERATE;
    END GENERATE;

    -- =========================================================================
    -- Purpose: Add input digit to the intermediate x10 of the previous digit.
    -- Type:    combinational
    -- Inputs:  s_digits, s_mul_out
    -- Outputs: s_add_out
    -- =========================================================================
    add_together : FOR i IN N_BCD - 2 DOWNTO 0 GENERATE
        s_add_out(i) <= s_digits(i) + s_mul_out(i + 1);
    END GENERATE;

    -- =========================================================================
    -- Purpose: Make output signed. MSB of bcd input marks signedness.
    -- Type:    combinational
    -- Inputs:  s_add_out, bcd
    -- Outputs: bin
    -- =========================================================================
    bin <= SIGNED(s_add_out(0)) WHEN bcd(bcd'HIGH) = '0' ELSE
        - SIGNED(s_add_out(0));

END ARCHITECTURE no_target_specific;
