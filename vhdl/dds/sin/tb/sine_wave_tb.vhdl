-- =============================================================================
-- File:                    sine_wave_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  sine_wave_tb
--
-- Description:             Testbench for sine_wave entity. Checks together with
--                          the math_real library sin() function if the sine
--                          reconstructed from LUT is accurate with only a small
--                          error (+-4).
--
-- Changes:                 0.1, 2022-05-16, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

ENTITY sine_wave_tb IS
    -- Testbench needs no ports.
END ENTITY sine_wave_tb;

ARCHITECTURE simulation OF sine_wave_tb IS
    -- Component definition for device under test.
    COMPONENT sine_wave
        GENERIC (
            N_BITS : POSITIVE := 10
        );
        PORT (
            clock : IN STD_LOGIC;
            phase : IN UNSIGNED(N_BITS - 1 DOWNTO 0);
            data  : OUT UNSIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT sine_wave;
    -- Signals for sequential DUTs.
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    -- Signals for connecting to the DUT.
    CONSTANT c_n_bits : POSITIVE := 10;
    SIGNAL s_phase, s_data : UNSIGNED(c_n_bits - 1 DOWNTO 0) := (OTHERS => '0');
    -- Allowed error of difference between calculated and DUT sine wave.
    CONSTANT c_allowed_error : POSITIVE := 4;
BEGIN
    -- Instantiate the device under test.
    dut : sine_wave
    GENERIC MAP(
        N_BITS => c_n_bits
    )
    PORT MAP(
        clock => s_clock,
        phase => s_phase,
        data  => s_data
    );

    -- Clock with 50 MHz.
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 10 ns;

    -- Power on reset the DUT, lasts two clock cycles.
    s_n_reset <= '0', '1' AFTER 40 ns;

    test : PROCESS IS
        -- Proceudre that generates stimuli (phase value) for the DUT. The
        -- returned sine value will be compared with sin() from math_real.
        PROCEDURE check (
            CONSTANT phase : INTEGER -- phase in range [0 2^N-1]
        ) IS
            CONSTANT c_max_phase : POSITIVE := (2 ** c_n_bits) - 1;
            CONSTANT c_max_value : POSITIVE := (2 ** c_n_bits) - 1;
            VARIABLE v_sin_real : REAL;
            VARIABLE v_sin_int : INTEGER;
        BEGIN
            -- Set dut phase input.
            s_phase <= to_unsigned(phase, c_n_bits);
            WAIT UNTIL rising_edge(s_clock);
            WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
            -- Calculate sine for current phase.
            v_sin_real := sin(REAL(phase) * 2.0 * MATH_PI / REAL(c_max_phase));
            -- Map from float range [-1 +1] to integer range [0 2^N-1].
            v_sin_int := INTEGER(round(0.5 * (v_sin_real + 1.0) * REAL(c_max_value)));
            -- Check that the sine value is where it should be, but allow a
            -- small error.
            ASSERT ABS(to_integer(s_data) - v_sin_int) < c_allowed_error
            REPORT "Expected sine at phase " & INTEGER'image(phase) &
                " to be " & INTEGER'image(v_sin_int) & ". But it was " &
                INTEGER'image(to_integer(s_data)) &
                " which is off by more than the allowed error of " &
                INTEGER'image(c_allowed_error) & "."
                SEVERITY failure;
        END PROCEDURE check;
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(s_n_reset);

        -- Check every possible phase times.
        FOR i IN 2 ** c_n_bits - 1 DOWNTO 0 LOOP
            check(i);
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
