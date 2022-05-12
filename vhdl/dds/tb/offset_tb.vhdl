-- =============================================================================
-- File:                    offset_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  offset_tb
--
-- Description:             Testbench for offset entity. Checks if the value
--                          offset is applied correctly and within range.
--
-- Changes:                 0.1, 2022-05-08, leuen4
--                              initial implementation
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
            x      : IN UNSIGNED(N_BITS - 1 DOWNTO 0);
            offset : IN UNSIGNED(N_BITS - 1 DOWNTO 0);
            y      : OUT UNSIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT offset;
    -- Signals for connecting to the DUT.
    CONSTANT c_n_bits : POSITIVE := 10;
    CONSTANT c_max : POSITIVE := 2 ** c_n_bits - 1;
    SIGNAL s_x, s_offset, s_y : unsigned(c_n_bits - 1 DOWNTO 0) := (OTHERS => '0');
BEGIN
    -- Instantiate the device under test.
    dut : offset
    GENERIC MAP(
        N_BITS    => c_n_bits,
        VALUE_MAX => c_max
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
            -- Sequence of bits to stimulate the DUT with.
            CONSTANT x      : INTEGER; -- input value
            CONSTANT offset : INTEGER; -- offset to apply
            CONSTANT y      : INTEGER  -- expected output
        ) IS
        BEGIN
            s_x <= to_unsigned(x, c_n_bits);
            s_offset <= to_unsigned(offset, c_n_bits);
            WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
            ASSERT s_y = to_unsigned(y, c_n_bits)
            REPORT "Expected y to be " & INTEGER'image(y) & " but got " &
                INTEGER'image(to_integer(s_y)) & "."
                SEVERITY failure;
        END PROCEDURE check;
    BEGIN
        -- Check that every possible combination of input value and offset
        -- results in the correct y = x + offset but only as long as it stays
        -- below the maximum.
        FOR i IN 2 ** c_n_bits - 1 DOWNTO 0 LOOP
            FOR j IN 2 ** c_n_bits - 1 DOWNTO 0 LOOP
                IF i + j < c_max THEN
                    check(i, j, i + j);
                ELSE
                    check(i, j, c_max);
                END IF;
            END LOOP;
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
