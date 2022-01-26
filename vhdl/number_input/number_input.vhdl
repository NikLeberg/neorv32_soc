-- =============================================================================
-- File:                    number_input.vhdl
--
-- Authors:                 Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  number_input
--
-- Description:             Holds / saves the last sequentially entered digits
--                          from the keypad. As internally a shift register is
--                          used, if more than the defined number of digits are
--                          entered, the oldest digit is dropped.
--
-- Changes:                 0.1, 2021-12-10, reusa1
--                              initial version
--                          0.2, 2022-01-26, reusa1
--                              implement shift register
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY number_input IS
    GENERIC (
        num_bits : POSITIVE := 8;
        -- number of digits
        num_bcd : POSITIVE := 3
    );
    PORT (
        clock   : IN STD_LOGIC;
        n_reset : IN STD_LOGIC;
        number  : IN UNSIGNED(3 DOWNTO 0);
        pressed : IN STD_LOGIC; -- 1 if a new number was pressed

        bin : OUT SIGNED(num_bits - 1 DOWNTO 0)
    );
END ENTITY number_input;

ARCHITECTURE no_target_specific OF number_input IS
    SIGNAL s_shift_reg : STD_LOGIC_VECTOR(num_bcd * 4 DOWNTO 0);
    -- define component bcd_to_bin
    COMPONENT bcd_to_bin IS
        GENERIC (
            num_bits : POSITIVE;
            num_bcd  : POSITIVE
        );
        PORT (
            bcd : IN STD_LOGIC_VECTOR(num_bcd * 4 DOWNTO 0);
            bin : OUT SIGNED(num_bits - 1 DOWNTO 0)
        );
    END COMPONENT bcd_to_bin;
BEGIN
    shift_reg : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_shift_reg <= (OTHERS => '0');
                ELSIF (pressed = '1') THEN
                s_shift_reg(num_bcd * 4 - 1 DOWNTO 4) <= s_shift_reg(num_bcd * 4 - 5 DOWNTO 0);
                s_shift_reg(3 DOWNTO 0) <= STD_LOGIC_VECTOR(number);
                s_shift_reg(num_bcd * 4) <= '0'; -- is always positive
            END IF;
        END IF;
    END PROCESS shift_reg;

    converter : bcd_to_bin
    GENERIC MAP(
        num_bits => num_bits,
        num_bcd  => num_bcd
    )
    PORT MAP(
        bcd => s_shift_reg,
        bin => bin
    );

END ARCHITECTURE no_target_specific;
