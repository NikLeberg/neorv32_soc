-- =============================================================================
-- File:                    sine_wave.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  sine_wave
--
-- Description:             Sine wave for Direct Digital Synthesis. The wave
--                          with a range of [0 2*pi] gets reconstructed from the
--                          first quarter of a sine (range of [0 pi/2]) from a
--                          LUT. See entity lut_sine.
--
-- Changes:                 0.1, 2022-05-15, leuen4
--                              initial implementation
--                          0.2, 2022-05-17, leuen4
--                              Change output port from UNSIGNED to SIGNED. This
--                              allows for easier post processing by offset and
--                              gain manipulation.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY sine_wave IS
    GENERIC (
        -- Width of phase and amplitude.
        N_BITS : POSITIVE := 10
    );
    PORT (
        clock : IN STD_LOGIC;
        phase : IN UNSIGNED(N_BITS - 1 DOWNTO 0);
        data  : OUT SIGNED(N_BITS - 1 DOWNTO 0)
    );
END ENTITY sine_wave;

ARCHITECTURE no_target_specific OF sine_wave IS
    -- Define component lut_sine.
    COMPONENT lut_sine IS
        GENERIC (
            N_BITS_ADDRESS : POSITIVE;
            N_BITS_VALUE   : POSITIVE
        );
        PORT (
            clock : IN STD_LOGIC;

            addr_a, addr_b : IN UNSIGNED(N_BITS_ADDRESS - 1 DOWNTO 0);
            data_a, data_b : OUT UNSIGNED(N_BITS_VALUE - 1 DOWNTO 0)
        );
    END COMPONENT lut_sine;
    -- Signals to connect to the lut_sine.
    SIGNAL s_lut_addr : UNSIGNED(N_BITS - 3 DOWNTO 0);
    SIGNAL s_lut_data : UNSIGNED(N_BITS - 2 DOWNTO 0);
    -- Helper signals, these are used to split the phase in two parts.
    SIGNAL s_phase_upper : STD_LOGIC_VECTOR(1 DOWNTO 0); -- upper two bits
    SIGNAL s_phase_lower : UNSIGNED(N_BITS - 3 DOWNTO 0); -- lower bits
    -- Maximum value of the lower phase (N - 2) bits.
    CONSTANT c_phase_lower_max : UNSIGNED(N_BITS - 3 DOWNTO 0) := to_unsigned(2 ** (N_BITS - 2) - 1, N_BITS - 2);
BEGIN

    -- Instantiate sine LUT.
    lut_sine1 : lut_sine
    GENERIC MAP(
        N_BITS_ADDRESS => N_BITS - 2, -- see note in lut_sine
        N_BITS_VALUE   => N_BITS - 1  -- see note in lut_sine
    )
    PORT MAP(
        clock  => clock,
        addr_a => s_lut_addr,
        addr_b => (OTHERS => '0'), -- port B is unused for now
        data_a => s_lut_data,
        data_b => OPEN
    );

    -- =========================================================================
    -- Purpose: Helper signals for phase, 2 MSBs and rest of LSBs.
    -- Type:    combinational
    -- Inputs:  phase
    -- Outputs: s_phase_upper, s_phase_lower
    -- =========================================================================
    s_phase_upper <= STD_LOGIC_VECTOR(phase(N_BITS - 1 DOWNTO N_BITS - 2));
    s_phase_lower <= phase(N_BITS - 3 DOWNTO 0);

    -- =========================================================================
    -- Purpose: Reconstruct full sine wave from the quarter that is in LUT.
    -- Type:    combinational
    -- Inputs:  s_phase_upper, s_phase_lower, s_lut_data
    -- Outputs: s_lut_addr, data
    -- =========================================================================
    wave_reconstruct : PROCESS (s_phase_upper, s_phase_lower, s_lut_data) IS
    BEGIN
        CASE s_phase_upper IS
            WHEN "00" => -- First quarter, LUT.
                s_lut_addr <= s_phase_lower;
                data <= SIGNED('0' & s_lut_data);
            WHEN "01" => -- Second quarter, inverted LUT.
                s_lut_addr <= c_phase_lower_max - s_phase_lower;
                data <= SIGNED('0' & s_lut_data);
            WHEN "10" => -- Third quarter, negative LUT.
                s_lut_addr <= s_phase_lower;
                data <= - SIGNED('0' & s_lut_data);
            WHEN "11" => -- Fourth quarter, negative inverted LUT.
                s_lut_addr <= c_phase_lower_max - s_phase_lower;
                data <= - SIGNED('0' & s_lut_data);
            WHEN OTHERS => -- Invalid signals.
                s_lut_addr <= (OTHERS => '0');
                data <= (OTHERS => '0');
        END CASE;
    END PROCESS wave_reconstruct;

END ARCHITECTURE no_target_specific;
