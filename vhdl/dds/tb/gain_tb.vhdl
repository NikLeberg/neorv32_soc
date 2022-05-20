-- =============================================================================
-- File:                    gain_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  gain_tb
--
-- Description:             Testbench for gain entity. Checks if the gain is
--                          applied correctly to the value.
--
-- Changes:                 0.1, 2022-05-20, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY gain_tb IS
    -- Testbench needs no ports.
END ENTITY gain_tb;

ARCHITECTURE simulation OF gain_tb IS
    -- Component definition for device under test.
    COMPONENT gain
        GENERIC (
            N_BITS_VALUE : POSITIVE := 10;
            N_BITS_GAIN  : POSITIVE := 7
        );
        PORT (
            x    : IN SIGNED(N_BITS_VALUE - 1 DOWNTO 0);
            gain : IN UNSIGNED(N_BITS_GAIN - 1 DOWNTO 0);
            y    : OUT SIGNED(N_BITS_VALUE - 1 DOWNTO 0)
        );
    END COMPONENT gain;
    -- Signals for connecting to the DUT.
    CONSTANT c_n_bits_value : POSITIVE := 10;
    CONSTANT c_n_bits_gain : POSITIVE := 7;
    SIGNAL s_x, s_y : SIGNED(c_n_bits_value - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_gain : UNSIGNED(c_n_bits_gain - 1 DOWNTO 0) := (OTHERS => '0');
    -- Helper constants.
    CONSTANT c_value_min : INTEGER := - 2 ** (c_n_bits_value - 1);
    CONSTANT c_value_max : INTEGER := 2 ** (c_n_bits_value - 1) - 1;
    CONSTANT c_gain_min : INTEGER := 0;
    CONSTANT c_gain_max : INTEGER := 2 ** c_n_bits_gain - 1;
BEGIN
    -- Instantiate the device under test.
    dut : gain
    GENERIC MAP(
        N_BITS_VALUE => c_n_bits_value,
        N_BITS_GAIN  => c_n_bits_gain
    )
    PORT MAP(
        x    => s_x,
        gain => s_gain,
        y    => s_y
    );

    test : PROCESS IS
        -- Procedure that generates stimuli for the given values. Response from
        -- DUT is checked for correctness.
        PROCEDURE check (
            CONSTANT x             : INTEGER; -- input value
            CONSTANT gain          : NATURAL; -- gain to apply
            CONSTANT y             : INTEGER; -- expected output
            CONSTANT allowed_error : NATURAL  -- maximum allowed error
        ) IS
        BEGIN
            s_x <= to_signed(x, c_n_bits_value);
            s_gain <= to_unsigned(gain, c_n_bits_gain);
            WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
            ASSERT ABS(to_integer(s_y) - y) <= allowed_error
            REPORT "Expected y to be " & INTEGER'image(y) & " but got " &
                INTEGER'image(to_integer(s_y)) &
                " which is off by more than the allowed error of " &
                INTEGER'image(allowed_error) & "."
                SEVERITY failure;
        END PROCEDURE check;
    BEGIN
        -- Multiplying with a value of 0 should always result in zero.
        FOR i IN c_value_max DOWNTO c_value_min LOOP
            check(i, 0, 0, 0);
        END LOOP;

        -- Multiplying by 0 should always result in zero.
        FOR i IN c_gain_max DOWNTO c_gain_min LOOP
            check(0, i, 0, 0);
        END LOOP;

        -- Multiplying by max gain should always result in the same as input.
        FOR i IN c_value_max DOWNTO c_value_min LOOP
            check(i, c_gain_max, i, 4);
        END LOOP;

        -- Multiplying by half gain should result in the half of the input.
        FOR i IN c_value_max DOWNTO c_value_min LOOP
            check(i, c_gain_max / 2, i / 2, 4);
        END LOOP;

        -- Multiplying by a quarter should result in the a quarter of the input.
        FOR i IN c_value_max DOWNTO c_value_min LOOP
            check(i, c_gain_max / 4, i / 4, 4);
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
