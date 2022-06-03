-- =============================================================================
-- File:                    bcd_to_7seg.vhdl
--
-- Authors:                 Adrian Reusser <reusa1@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  bcd_to_7seg
--
-- Description:             Converts a multi digit bcd value to the coresponding
--                          signals for multiple seven segment displays.
--
-- Note:                    This entity has no testbench. Reason being that it
--                          is obvious if something isnt working as intended
--                          i.e. wrong digits get displayed. This was tested
--                          manually and found to be working as intended.
--
-- Changes:                 0.1, 2021-12-15, reusa1
--                              initial version
--                          0.2, 2022-06-03, leuen4
--                              Extend with generic multi digit functionality.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY bcd_to_7seg IS
    GENERIC (
        N_BCD  : POSITIVE := 4; -- number of bcd digits = number of segments - 1
        N_DP   : NATURAL  := 0; -- what segment should display the decimal point
        E_SIGN : NATURAL  := 1  -- 1: additional segment that shows sign, 0: no
    );
    PORT (
        -- MSB is 1 if negative (only relevant for E_SIGN = 1 option).
        -- Rest is a multiple of 4 bits and each represent a bcd digit.
        bcd : IN STD_LOGIC_VECTOR(N_BCD * 4 DOWNTO 0);
        -- Vector of 7-segment (+DP) signals. N groups in the order (from MSB to
        -- LSB) of: A, B, C, D, E, F, G, DP. One additional segment is used as
        -- minus sign of option E_SIGN is set to 1.
        seg : OUT STD_LOGIC_VECTOR((N_BCD + E_SIGN) * 8 - 1 DOWNTO 0)
    );
END ENTITY bcd_to_7seg;

ARCHITECTURE no_target_specific OF bcd_to_7seg IS

BEGIN

    -- =========================================================================
    -- Purpose: Map bcd values to 7 segment signals and decimal point.
    -- Type:    combinational
    -- Inputs:  bcd
    -- Outputs: seg
    -- =========================================================================
    map_digits : PROCESS (bcd) IS
        -- Local static variable as case selector, otherwise modelsim complains.
        VARIABLE v_digit : STD_LOGIC_VECTOR(3 DOWNTO 0);
        VARIABLE v_segment : STD_LOGIC_VECTOR(6 DOWNTO 0);
    BEGIN
        FOR i IN N_BCD - 1 DOWNTO 0 LOOP
            -- Map each bcd digit to the signals for A, B, C, D, E, F, G.
            v_digit := bcd(i * 4 + 3 DOWNTO i * 4);
            CASE v_digit IS
                WHEN x"0" => v_segment := "1111110";
                WHEN x"1" => v_segment := "0110000";
                WHEN x"2" => v_segment := "1101101";
                WHEN x"3" => v_segment := "1111001";
                WHEN x"4" => v_segment := "0110011";
                WHEN x"5" => v_segment := "1011011";
                WHEN x"6" => v_segment := "1011111";
                WHEN x"7" => v_segment := "1110000";
                WHEN x"8" => v_segment := "1111111";
                WHEN x"9" => v_segment := "1111011";
                WHEN OTHERS => v_segment := "0000000";
            END CASE;
            seg(i * 8 + 7 DOWNTO i * 8 + 1) <= v_segment; -- no DP
            -- Set decimal point at the set place but not if it is last place.
            IF i = N_DP AND i /= 0 THEN
                seg(i * 8) <= '1';
            ELSE
                seg(i * 8) <= '0';
            END IF;
        END LOOP;
    END PROCESS map_digits;

    -- =========================================================================
    -- Purpose: Set negative sign in leftmost segment if option enabled.
    -- Type:    combinational
    -- Inputs:  bcd
    -- Outputs: seg (leftmost segment)
    -- =========================================================================
    sign_enabled : IF E_SIGN = 1 GENERATE
        -- MSB of bcd value signals the negative sign.
        seg(seg'HIGH DOWNTO seg'HIGH - 7) <= "00000000" WHEN bcd(bcd'HIGH) = '0' ELSE
            "00000010";
    END GENERATE;

END ARCHITECTURE no_target_specific;
