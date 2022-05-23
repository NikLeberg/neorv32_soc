-- =============================================================================
-- File:                    offset_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  offset_tb
--
-- Description:             Testbench for offset entity. Checks if the value
--                          offset is applied correctly and within range.
--
-- Changes:                 0.1, 2022-05-08, leuen4
--                              initial implementation
--                          0.2, 2022-05-23, leuen4
--                              Change tase because of DUT port change from
--                              UNSIGNED to SIGNED.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY offset_tb IS
    -- Testbench needs no ports.
END ENTITY offset_tb;

ARCHITECTURE simulation OF offset_tb IS
    -- Component definition for device under test.
    COMPONENT offset
        GENERIC (
            N_BITS    : POSITIVE;
            VALUE_MAX : POSITIVE
        );
        PORT (
            x      : IN SIGNED(N_BITS - 1 DOWNTO 0);
            offset : IN UNSIGNED(N_BITS - 2 DOWNTO 0);
            y      : OUT SIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT offset;
    -- Signals for connecting to the DUT.
    CONSTANT c_n_bits : POSITIVE := 10;
    SIGNAL s_x, s_y : SIGNED(c_n_bits - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_offset : UNSIGNED(c_n_bits - 2 DOWNTO 0) := (OTHERS => '0');
    -- Helper constants.
    CONSTANT c_value_min : INTEGER := - 2 ** (c_n_bits - 1);
    CONSTANT c_value_max : INTEGER := 2 ** (c_n_bits - 1) - 1;
    CONSTANT c_offset_min : INTEGER := 0;
    CONSTANT c_offset_max : INTEGER := 2 ** (c_n_bits - 1) - 1;
BEGIN
    -- Instantiate the device under test.
    dut : offset
    GENERIC MAP(
        N_BITS    => c_n_bits,
        VALUE_MAX => c_value_max
    )
    PORT MAP(
        x      => s_x,
        offset => s_offset,
        y      => s_y
    );

    test : PROCESS IS
        -- Procedure that generates stimuli for the given values. Response from
        -- DUT is checked for correctness.
        PROCEDURE check (
            CONSTANT x      : INTEGER; -- input value
            CONSTANT offset : INTEGER; -- offset to apply
            CONSTANT y      : INTEGER  -- expected output
        ) IS
        BEGIN
            s_x <= to_signed(x, c_n_bits);
            s_offset <= to_unsigned(offset, c_n_bits - 1);
            WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
            ASSERT s_y = to_signed(y, c_n_bits)
            REPORT "Expected y to be " & INTEGER'image(y) & " but got " &
                INTEGER'image(to_integer(s_y)) & "."
                SEVERITY failure;
        END PROCEDURE check;
    BEGIN
        -- Check that every possible combination of input value and offset
        -- results in the correct y = x + offset but only as long as it stays
        -- below the maximum.
        FOR i IN c_value_max DOWNTO c_value_min LOOP
            FOR j IN c_offset_max DOWNTO c_offset_min LOOP
                IF i + j < c_value_max THEN
                    check(i, j, i + j);
                ELSE
                    check(i, j, c_value_max);
                END IF;
            END LOOP;
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
