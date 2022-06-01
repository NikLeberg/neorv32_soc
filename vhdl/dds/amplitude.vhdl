-- =============================================================================
-- File:                    amplitude.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.3
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
--                          0.2, 2022-05-19, leuen4
--                              Change output port from UNSIGNED to SIGNED. This
--                              allows for easier post processing by offset and
--                              gain manipulation.
--                          0.3, 2022-06-01, leuen4
--                              Add missing generic NBITS in sine_wave instance.
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
        amp      : OUT SIGNED(N_BITS - 1 DOWNTO 0)   -- Amplitude of signal type
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
            data  : OUT SIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT sine_wave;
    -- Signals of the different signal types.
    SIGNAL s_sine : SIGNED(N_BITS - 1 DOWNTO 0);
    SIGNAL s_rectangle : SIGNED(N_BITS - 1 DOWNTO 0);
    SIGNAL s_triangle_helper : SIGNED(N_BITS - 1 DOWNTO 0); -- phase * 2
    SIGNAL s_triangle : SIGNED(N_BITS - 1 DOWNTO 0);
    SIGNAL s_sawtooth : SIGNED(N_BITS - 1 DOWNTO 0);
    -- Helper constants.
    CONSTANT c_amp_max : SIGNED(N_BITS - 1 DOWNTO 0) := to_signed((2 ** (N_BITS - 1)) - 1, N_BITS);
    CONSTANT c_amp_min : SIGNED(N_BITS - 1 DOWNTO 0) := to_signed((-2 ** (N_BITS - 1)), N_BITS);
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
        N_BITS => N_BITS
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
    s_rectangle <= c_amp_max WHEN phase(phase'HIGH) = '0' ELSE
        c_amp_min;

    -- =========================================================================
    -- Purpose: Signal generation for triangle type
    -- Type:    combinational
    -- Inputs:  phase
    -- Outputs: s_triangle
    -- =========================================================================
    -- When the first two bits of phase are identical we are in the first and
    -- fourth quarter of the phase. There just use the phase shifted one to the
    -- left. Explicid UNSIGNED to SIGNED will cause the fourth quarter to be
    -- negative. In the second and third quarter of the phase use the negative
    -- of the shifted phase. Explicid SIGNED conversation causes a correct wave.
    s_triangle_helper <= SIGNED(phase(phase'HIGH - 1 DOWNTO 0) & '1');
    s_triangle <= s_triangle_helper WHEN phase(phase'HIGH) = phase(phase'HIGH - 1) ELSE
        - s_triangle_helper;

    -- =========================================================================
    -- Purpose: Signal generation for sawtooth type
    -- Type:    combinational
    -- Inputs:  phase
    -- Outputs: s_sawtooth
    -- =========================================================================
    s_sawtooth <= SIGNED(phase); -- maximum simplicity

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
