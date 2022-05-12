-- =============================================================================
-- File:                    phase_acc_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  phase_acc_tb
--
-- Description:             Testbench for phase_acc entity. Checks if the phase
--                          is monotonically increasing with a constant
--                          configurable rate.
--
-- Changes:                 0.1, 2022-05-08, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY phase_acc_tb IS
    -- Testbench needs no ports.
END ENTITY phase_acc_tb;

ARCHITECTURE simulation OF phase_acc_tb IS
    -- Component definition for device under test.
    COMPONENT phase_acc
        GENERIC (
            N_BITS : POSITIVE
        );
        PORT (
            clock, n_reset : IN STD_LOGIC;

            delta_phase : IN UNSIGNED(N_BITS - 1 DOWNTO 0);
            phase       : OUT UNSIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT phase_acc;
    -- Signals for sequential DUTs.
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    -- Signals for connecting to the DUT.
    CONSTANT c_n_bits : POSITIVE := 10;
    SIGNAL s_delta_phase, s_phase : UNSIGNED(c_n_bits - 1 DOWNTO 0) := (OTHERS => '0');
BEGIN
    -- Instantiate the device under test.
    dut : phase_acc
    GENERIC MAP(
        N_BITS => c_n_bits
    )
    PORT MAP(
        clock       => s_clock,
        n_reset     => s_n_reset,
        delta_phase => s_delta_phase,
        phase       => s_phase
    );

    -- Clock with 50 MHz.
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 10 ns;

    -- Power on reset the DUT, lasts two clock cycles.
    s_n_reset <= '0', '1' AFTER 40 ns;

    test : PROCESS IS
        -- Procedure that generates stimuli for the given delta. Response from
        -- DUT is checked for correctness.
        VARIABLE v_last_phase : INTEGER := 0;
        PROCEDURE check (
            CONSTANT delta : INTEGER -- delta that should be added every clock
        ) IS
            VARIABLE v_phase : INTEGER;
        BEGIN
            -- Set dut delta input.
            s_delta_phase <= to_unsigned(delta, c_n_bits);
            WAIT UNTIL rising_edge(s_clock);
            WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
            -- Check that the phase increased exactly with delta (with optional
            -- wrap around).
            v_phase := to_integer(s_phase);
            ASSERT (v_last_phase + delta) MOD 2 ** c_n_bits = v_phase
            REPORT "Expected phase to increase with " & INTEGER'image(delta) &
                ". But phase of " & INTEGER'image(v_last_phase) &
                " has increased to " & INTEGER'image(v_phase) & "."
                SEVERITY failure;
            -- Save current phase for next procedure call.
            v_last_phase := to_integer(s_phase);
        END PROCEDURE check;
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(s_n_reset);

        -- Check every possible phase delta ten times.
        FOR i IN 2 ** c_n_bits - 1 DOWNTO 0 LOOP
            FOR j IN 9 DOWNTO 0 LOOP
                check(i);
            END LOOP;
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
