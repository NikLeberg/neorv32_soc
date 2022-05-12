-- =============================================================================
-- File:                    delta_phase_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  delta_phase_tb
--
-- Description:             Testbench for delta_phase entity. Checks if the
--                          delta phase (or tuning word) is correctly calculated
--                          as delta = frequency * 86.
--
-- Changes:                 0.1, 2022-05-12, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY delta_phase_tb IS
    -- Testbench needs no ports.
END ENTITY delta_phase_tb;

ARCHITECTURE simulation OF delta_phase_tb IS
    -- Component definition for device under test.
    COMPONENT delta_phase
        PORT (
            f           : IN UNSIGNED(32 - 1 DOWNTO 0);
            delta_phase : OUT UNSIGNED(32 - 1 DOWNTO 0)
        );
    END COMPONENT delta_phase;
    -- Signals for connecting to the DUT.
    CONSTANT c_n_bits : POSITIVE := 32;
    SIGNAL s_f, s_delta_phase : UNSIGNED(c_n_bits - 1 DOWNTO 0) := (OTHERS => '0');
BEGIN
    -- Instantiate the device under test.
    dut : delta_phase
    PORT MAP(
        f           => s_f,
        delta_phase => s_delta_phase
    );

    test : PROCESS IS
        -- Procedure that generates stimuli for the given frequency. Delta phase
        -- output from DUT is checked if its equal to f * 86.
        PROCEDURE check (CONSTANT f : INTEGER) IS -- f: desired frequency
        BEGIN
            s_f <= to_unsigned(f, c_n_bits);
            WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
            ASSERT to_integer(s_delta_phase) = f * 86
            REPORT "Expected delta phase to be " & INTEGER'image(f * 86) &
                " but got " & INTEGER'image(to_integer(s_delta_phase)) & "."
                SEVERITY failure;
        END PROCEDURE check;
    BEGIN
        -- Check every possible input frequency in the range 100 kHz - 1 Hz.
        FOR i IN 100000 DOWNTO 0 LOOP
            check(i);
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
