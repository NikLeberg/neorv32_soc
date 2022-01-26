-- =============================================================================
-- File:                    bcd_to_bin.vhdl
--
-- Authors:                 Adrian Reusser
--
-- Version:                 0.1
--
-- Entity:                  bcd_to_bin
--
-- Description:             Transform the given bcd value back to a binary value
--                          by multiplying each bcd value by (1, 10 or 100). We 
--                          could have taken the same algorhytm as bin_to_bcd
--                          and reverse it. But we decided, to use our own 
--                          multiplication to calculate the binary value.
--
-- Changes:                
-- =============================================================================
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.datatypes.ALL;

ENTITY bcd_to_bin IS
    GENERIC (
        num_bits : POSITIVE := 8;
        num_bcd  : POSITIVE := 3
    );
    PORT (
        bcd : IN STD_LOGIC_VECTOR(num_bcd * 4 DOWNTO 0);
        bin : OUT SIGNED(num_bits - 1 DOWNTO 0)
    );
END ENTITY bcd_to_bin;

ARCHITECTURE no_target_specific OF bcd_to_bin IS
    TYPE add_result_type IS ARRAY (NATURAL RANGE <>) OF SIGNED(num_bits - 1 DOWNTO 0);
    SIGNAL s_result : add_result_type (num_bcd - 1 DOWNTO 0);
    SIGNAL s_a : add_result_type (num_bcd - 1 DOWNTO 0);

    --the multiplication component is added in oder to use multiplication later
    COMPONENT math_mul
        PORT (
            a, b : IN SIGNED(num_bits - 1 DOWNTO 0);
            y    : OUT SIGNED(num_bits - 1 DOWNTO 0)
        );
    END COMPONENT math_mul;
BEGIN
    --
    add_mul : FOR i IN num_bcd - 1 DOWNTO 0 GENERATE
        digit_0 : IF i = 0 GENERATE
            --the first digit can be left as it is. It needs no multiplication, 
            --but the number has to be risized. 
            s_result(i)(3 DOWNTO 0) <= signed(bcd(3 DOWNTO 0));
            s_result(i)(num_bits - 1 DOWNTO 4) <= (OTHERS => '0');
        END GENERATE;
        --multiple instances of the multiplication are generated in order to 
        --multiply various digits with the respective 10er potence
        digit_rest : IF i /= 0 GENERATE
            --enlarge the incoming signal to fit the multiplication
            s_a(i)(3 DOWNTO 0) <= signed(bcd(4 * i + 3 DOWNTO 4 * i));
            s_a(i)(num_bits - 1 DOWNTO 4) <= (OTHERS => '0');
            -- s_a(i) <= resize(signed(bcd(4 * i + 3 DOWNTO 4 * i)), num_bits);
            math_mul_instance : math_mul
            GENERIC MAP(
                num_bits => num_bits
            )
            PORT MAP(
                --the ports of the multiplication unit are assigned to the 
                --respective signals. 
                a => s_a(i),
                b => to_signed(10 ** i, num_bits), --multiply potence of 10
                y => s_result(i)
            );
        END GENERATE;
    END GENERATE;

    add_value : PROCESS (s_result, bcd) IS
        VARIABLE v_add : signed (num_bits - 1 DOWNTO 0);
    BEGIN
        --create a variable in order to sum the results
        v_add := to_signed(0, num_bits);
        --add the results of the multiplication together
        FOR i IN num_bcd - 1 DOWNTO 0 LOOP
            v_add := v_add + s_result(i);
        END LOOP;

        --differenciate between positive an negative values. Change the negatve 
        --values to negative
        IF (bcd(num_bcd * 4) = '0') THEN
            bin <= v_add;
        ELSE
            bin <= - v_add;
        END IF;
    END PROCESS add_value;
END ARCHITECTURE no_target_specific;
