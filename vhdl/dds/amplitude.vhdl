-- =============================================================================
-- File:                    amplitude.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  amplitude
--
-- Description:             Phase to amplitude conversation for Direct Digital
--                          Synthesis. Depending in the choosen signal type a
--                          sine, rect, triangle or sawtooth signal is generated
--                          from the phase input.
--
-- Changes:                 0.1, 2022-05-09, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY amplitude IS
    GENERIC (
        N_BITS : POSITIVE := 10 -- width of phase and amplitude
    );
    PORT (
        clock, n_reset : IN STD_LOGIC;

        -- Signal type is one of:
        -- "00": Sine, "01": Rectangle, "10": Triangle, "11": Sawtooth
        sig_type : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        phase    : IN UNSIGNED(N_BITS - 1 DOWNTO 0); -- MSB's of phase
        amp      : OUT UNSIGNED(N_BITS - 1 DOWNTO 0) -- Amplitude of signal type
    );
END ENTITY amplitude;

ARCHITECTURE no_target_specific OF amplitude IS
    -- define component lut_sin_gen
    COMPONENT sine_wave IS
        GENERIC (
            N_BITS : POSITIVE
        );
        PORT (
            clock : IN STD_LOGIC;
            phase : IN UNSIGNED(N_BITS - 1 DOWNTO 0);
            data  : OUT UNSIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT sine_wave;
    -- Signals of the different signal types.
    SIGNAL s_sine : UNSIGNED(N_BITS - 1 DOWNTO 0);
    SIGNAL s_rectangle : UNSIGNED(N_BITS - 1 DOWNTO 0);
    SIGNAL s_triangle : UNSIGNED(N_BITS - 1 DOWNTO 0);
    SIGNAL s_sawtooth : UNSIGNED(N_BITS - 1 DOWNTO 0);
    CONSTANT c_amp_max : UNSIGNED(N_BITS - 1 DOWNTO 0) := to_unsigned(2 ** N_BITS - 1, N_BITS);
BEGIN

    -- =========================================================================
    -- Purpose: Signal generation for sine type
    -- Type:    sequential
    -- Inputs:  clock, phase
    -- Outputs: s_sine
    -- =========================================================================
    -- Note: Sine lags one clock behind as underlying LUT is sequential entity!
    sine1 : sine_wave
    GENERIC MAP(
        N_BITS => 10
    )
    PORT MAP(
        clock => clock,
        phase => phase,
        data  => s_sine
    );

    -- =========================================================================
    -- Purpose: Signal generation for rectangle type
    -- Type:    combinational
    -- Inputs:  phase
    -- Outputs: s_rectangle
    -- =========================================================================
    -- MSB of phase determines signal level.
    s_rectangle <= (OTHERS => '0') WHEN phase(phase'HIGH) = '0' ELSE
        (OTHERS => '1');

    -- =========================================================================
    -- Purpose: Signal generation for triangle type
    -- Type:    combinational
    -- Inputs:  phase
    -- Outputs: s_triangle
    -- =========================================================================
    -- For first half of the phase just double it (left shift 1 bit) and for the
    -- second half subtract the doubled phase (withouh MSB) from the max value.
    s_triangle <= (phase(phase'HIGH - 1 DOWNTO 0) & '0') WHEN phase(phase'HIGH) = '0' ELSE
        c_amp_max - (phase(phase'HIGH - 1 DOWNTO 0) & '0');

    -- =========================================================================
    -- Purpose: Signal generation for sawtooth type
    -- Type:    combinational
    -- Inputs:  phase
    -- Outputs: s_sawtooth
    -- =========================================================================
    s_sawtooth <= phase; -- maximum simplicity

    -- =========================================================================
    -- Purpose: Output logic for signal type selection
    -- Type:    combinational
    -- Inputs:  sig_type, s_sine, s_rectangle, s_triangle, s_sawtooth
    -- Outputs: amp
    -- =========================================================================
    -- "00": Sine, "01": Rectangle, "10": Triangle, "11": Sawtooth
    amp <= s_sine WHEN sig_type = "00" ELSE
        s_rectangle WHEN sig_type = "01" ELSE
        s_triangle WHEN sig_type = "10" ELSE
        s_sawtooth WHEN sig_type = "11" ELSE
        (OTHERS => '0');
END ARCHITECTURE no_target_specific;
