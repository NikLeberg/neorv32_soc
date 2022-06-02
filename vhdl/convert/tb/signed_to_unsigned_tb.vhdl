-- =============================================================================
-- File:                    signed_to_unsigned_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  signed_to_unsigned_tb
--
-- Description:             Testbench for signed_to_unsigned entity. Checks if
--                          a signed value is correctly converted to a unsigned.
--
-- Changes:                 0.1, 2022-06-01, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY signed_to_unsigned_tb IS
    -- Testbench needs no ports.
END ENTITY signed_to_unsigned_tb;

ARCHITECTURE simulation OF signed_to_unsigned_tb IS
    -- Component definition for device under test.
    COMPONENT signed_to_unsigned
        GENERIC (
            N_BITS_SIGNED   : POSITIVE;
            N_BITS_UNSIGNED : POSITIVE
        );
        PORT (
            x : IN SIGNED(N_BITS_SIGNED - 1 DOWNTO 0);
            y : OUT UNSIGNED(N_BITS_UNSIGNED - 1 DOWNTO 0)
        );
    END COMPONENT signed_to_unsigned;
    -- Signals for connecting to the DUT.
    CONSTANT c_n_bits_signed : POSITIVE := 12;
    CONSTANT c_n_bits_unsigned : POSITIVE := 10;
    SIGNAL s_x : SIGNED(c_n_bits_signed - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_y : UNSIGNED(c_n_bits_unsigned - 1 DOWNTO 0) := (OTHERS => '0');
    -- Helper constants.
    CONSTANT c_signed_max : INTEGER := 2 ** (c_n_bits_signed - 1) - 1;
    CONSTANT c_signed_min : INTEGER := - 2 ** (c_n_bits_signed - 1);
    CONSTANT c_unsigned_max : INTEGER := 2 ** c_n_bits_unsigned - 1;
BEGIN
    -- Instantiate the device under test.
    dut : signed_to_unsigned
    GENERIC MAP(
        N_BITS_SIGNED   => c_n_bits_signed,
        N_BITS_UNSIGNED => c_n_bits_unsigned
    )
    PORT MAP(
        x => s_x,
        y => s_y
    );

    test : PROCESS IS
        -- Procedure that generates stimuli for the given values. Response from
        -- DUT is checked for correctness.
        PROCEDURE check (
            CONSTANT x : INTEGER; -- input value
            CONSTANT y : NATURAL  -- expected output
        ) IS
        BEGIN
            s_x <= to_signed(x, c_n_bits_signed);
            WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
            ASSERT to_integer(s_y) = y
            REPORT "With an x of " & INTEGER'image(x) &
                " y was expected to be " & INTEGER'image(y) & " but was " &
                INTEGER'image(to_integer(s_y)) & "."
                SEVERITY failure;
        END PROCEDURE check;
    BEGIN

        -- Check for every possible input. If it is greater than 0 the output
        -- should match the input and only be scaled down. The down scaling
        -- factor comes from the lost LSB bits during conversation.
        FOR i IN c_signed_max DOWNTO c_signed_min LOOP
            IF i > 0 THEN
                check(i, i / (2 ** (c_n_bits_signed - c_n_bits_unsigned - 1)));
            ELSE
                check(i, 0);
            END IF;
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
