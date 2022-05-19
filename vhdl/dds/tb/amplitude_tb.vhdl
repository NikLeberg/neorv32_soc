-- =============================================================================
-- File:                    amplitude_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  amplitude_tb
--
-- Description:             Testbench for amplitude entity. Checks weather the
--                          generated waves of type rectangle, triangle or
--                          sawtooth are correct. Sine wave is not checked as it
--                          is already tested with testbench sine_wave_tb.
--
-- Changes:                 0.1, 2022-05-16, leuen4
--                              initial implementation
--                          0.2, 2022-05-19, leuen4
--                              Output port changed from UNSIGNED to SIGNED.
--                              Change checks to match the now signed amplitude.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

ENTITY amplitude_tb IS
    -- Testbench needs no ports.
END ENTITY amplitude_tb;

ARCHITECTURE simulation OF amplitude_tb IS
    -- Component definition for device under test.
    COMPONENT amplitude
        GENERIC (
            N_BITS : POSITIVE := 10
        );
        PORT (
            clock, n_reset : IN STD_LOGIC;

            sig_type : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            phase    : IN UNSIGNED(N_BITS - 1 DOWNTO 0);
            amp      : OUT SIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT amplitude;
    -- Signals for sequential DUTs.
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    -- Signals for connecting to the DUT.
    CONSTANT c_n_bits : POSITIVE := 10;
    SIGNAL s_sig_type : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL s_phase : UNSIGNED(c_n_bits - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_amp : SIGNED(c_n_bits - 1 DOWNTO 0) := (OTHERS => '0');
BEGIN
    -- Instantiate the device under test.
    dut : amplitude
    GENERIC MAP(
        N_BITS => c_n_bits
    )
    PORT MAP(
        clock    => s_clock,
        n_reset  => s_n_reset,
        sig_type => s_sig_type,
        phase    => s_phase,
        amp      => s_amp
    );

    -- Clock with 50 MHz.
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 10 ns;

    -- Power on reset the DUT, lasts two clock cycles.
    s_n_reset <= '0', '1' AFTER 40 ns;

    test : PROCESS IS
        -- Proceudure that generates stimuli (phase value) for the DUT. The
        -- returned amplitude value will be compared with expected value.
        PROCEDURE check (
            -- "00": Sine, "01": Rectangle, "10": Triangle, "11": Sawtooth
            CONSTANT sig_type      : STD_LOGIC_VECTOR(1 DOWNTO 0);
            CONSTANT phase         : NATURAL; -- phase in range [0 2^N-1]
            CONSTANT expected      : INTEGER; -- expected value
            CONSTANT allowed_error : NATURAL  -- maximum error
        ) IS
        BEGIN
            -- Set dut inputs.
            s_phase <= to_unsigned(phase, c_n_bits);
            s_sig_type <= sig_type;
            WAIT UNTIL rising_edge(s_clock);
            WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
            -- Check that the amplitude value is where it should be, but allow a
            -- small error.
            ASSERT ABS(to_integer(s_amp) - expected) <= allowed_error
            REPORT "Expected wave of type " & INTEGER'image(to_integer(UNSIGNED(sig_type))) &
                " at phase " & INTEGER'image(phase) & " to be " &
                INTEGER'image(expected) & ". But it was " &
                INTEGER'image(to_integer(s_amp)) &
                " which is off by more than the allowed error of " &
                INTEGER'image(allowed_error) & "."
                SEVERITY failure;
        END PROCEDURE check;
        -- Helper constants.
        CONSTANT c_value_min : INTEGER := (-2 ** (c_n_bits - 1));
        CONSTANT c_value_max : INTEGER := (2 ** (c_n_bits - 1)) - 1;
        CONSTANT c_phase_min : NATURAL := 0;
        CONSTANT c_phase_one_fourth : NATURAL := 2 ** (c_n_bits - 2);
        CONSTANT c_phase_two_fourths : NATURAL := 2 * c_phase_one_fourth;
        CONSTANT c_phase_three_fourths : NATURAL := 3 * c_phase_one_fourth;
        CONSTANT c_phase_max : NATURAL := (2 ** c_n_bits) - 1;
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(s_n_reset);

        -- Rectangle
        FOR i IN c_phase_min TO c_phase_two_fourths - 1 LOOP
            check("01", i, c_value_max, 0);
        END LOOP;
        FOR i IN c_phase_two_fourths TO c_phase_max LOOP
            check("01", i, c_value_min, 0);
        END LOOP;

        -- Triangle
        check("10", c_phase_min, 0, 1);
        check("10", c_phase_one_fourth, c_value_max, 1);
        check("10", c_phase_two_fourths, 0, 1);
        check("10", c_phase_three_fourths, c_value_min, 1);
        check("10", c_phase_max, 0, 1);

        -- Sawtooth
        FOR i IN c_phase_min TO c_phase_two_fourths - 1 LOOP
            check("11", i, i, 0);
        END LOOP;
        FOR i IN c_phase_two_fourths TO c_phase_max LOOP
            check("11", i, i + 2 * c_value_min, 0);
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
