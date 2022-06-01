-- =============================================================================
-- File:                    dds.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  dds
--
-- Description:             Direct Digital Synthesis generates a 12 bit analog
--                          output signal based on signal type, frequency, gain
--                          and offset.
--                          This and sub entities are loosely based on:
--                          https://www.analog.com/media/en/training-seminars/tutorials/MT-085.pdf
--
-- Note:                    Where easily possible, sub entities use generics for
--                          bit width and other parameters. This "top" entity
--                          sets the required generics such that it works
--                          together as an DDS.
--
-- Changes:                 0.1, 2022-04-28, leuen4
--                              initial implementation
--                          0.2, 2022-06-01, leuen4
--                              change value width to 12 bits
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY dds IS
    PORT (
        clock, n_reset : IN STD_LOGIC;

        -- Signal type is one of:
        -- "00": Sine, "01": Rectangle, "10": Triangle, "11": Sawtooth
        sig_type : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        -- Frequency in the range from 1 Hz up to 99'999 Hz in 1 Hz increments.
        frequency_in : IN UNSIGNED(16 DOWNTO 0);
        -- Amplitude gain in the range from 0 V to 1.25 V in 0.01 V increments.
        gain_in : IN UNSIGNED(6 DOWNTO 0);
        -- DC offset in the range from 0 V to 2.5 V in 0.01 V increments.
        offset_in : IN UNSIGNED(7 DOWNTO 0);

        -- DDS value to DAC
        value : OUT SIGNED(11 DOWNTO 0)
    );
END ENTITY dds;

ARCHITECTURE no_target_specific OF dds IS

    -- Definitions for sub entities.

    COMPONENT delta_phase IS
        PORT (
            frequency   : IN UNSIGNED(32 - 1 DOWNTO 0);
            delta_phase : OUT UNSIGNED(32 - 1 DOWNTO 0)
        );
    END COMPONENT delta_phase;

    COMPONENT phase_acc IS
        GENERIC (
            N_BITS : POSITIVE
        );
        PORT (
            clock, n_reset : IN STD_LOGIC;
            delta_phase    : IN UNSIGNED(N_BITS - 1 DOWNTO 0);
            phase          : OUT UNSIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT phase_acc;

    COMPONENT amplitude IS
        GENERIC (
            N_BITS : POSITIVE
        );
        PORT (
            clock, n_reset : IN STD_LOGIC;
            sig_type       : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            phase          : IN UNSIGNED(N_BITS - 1 DOWNTO 0);
            amp            : OUT SIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT amplitude;

    COMPONENT gain IS
        GENERIC (
            N_BITS_VALUE : POSITIVE;
            N_BITS_GAIN  : POSITIVE
        );
        PORT (
            x    : IN SIGNED(N_BITS_VALUE - 1 DOWNTO 0);
            gain : IN UNSIGNED(N_BITS_GAIN - 1 DOWNTO 0);
            y    : OUT SIGNED(N_BITS_VALUE - 1 DOWNTO 0)
        );
    END COMPONENT gain;

    COMPONENT offset
        GENERIC (
            N_BITS    : POSITIVE;
            VALUE_MAX : INTEGER;
            VALUE_MIN : INTEGER
        );
        PORT (
            x      : IN SIGNED(N_BITS - 1 DOWNTO 0);
            offset : IN SIGNED(N_BITS - 1 DOWNTO 0);
            y      : OUT SIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT offset;

    -- Constants of bit width and value ranges.
    CONSTANT c_n_phase : POSITIVE := 32; -- resolution of 11.6 mHz
    CONSTANT c_n_value : POSITIVE := 12; -- 2 bits more than DAC resolution
    CONSTANT c_n_gain : POSITIVE := 7; -- fits values from 0 ... 1.25 V (*10)

    -- Signals to connect sub entities and inputs together.
    SIGNAL s_frequency, s_delta_phase, s_phase : UNSIGNED(c_n_phase - 1 DOWNTO 0);
    SIGNAL s_phase_msbs : UNSIGNED(c_n_phase - 1 DOWNTO c_n_phase - c_n_value);
    SIGNAL s_amplitude, s_gained, s_offset, s_offsetted, s_value : SIGNED(c_n_value - 1 DOWNTO 0);

BEGIN

    -- Entity delta_phase expects input with 32 bits.
    s_frequency <= resize(frequency_in, c_n_phase);

    delta_phase1 : delta_phase
    PORT MAP(
        frequency   => s_frequency,
        delta_phase => s_delta_phase
    );

    phase_acc1 : phase_acc
    GENERIC MAP(
        N_BITS => c_n_phase
    )
    PORT MAP(
        clock       => clock,
        n_reset     => n_reset,
        delta_phase => s_delta_phase,
        phase       => s_phase
    );

    -- After phase accumulator only the top N=12 MSB bits are required.
    s_phase_msbs <= s_phase(c_n_phase - 1 DOWNTO c_n_phase - c_n_value);

    amplitude1 : amplitude
    GENERIC MAP(
        N_BITS => c_n_value
    )
    PORT MAP(
        clock    => clock,
        n_reset  => n_reset,
        sig_type => sig_type,
        phase    => s_phase_msbs,
        amp      => s_amplitude
    );

    gain1 : gain
    GENERIC MAP(
        N_BITS_VALUE => c_n_value,
        N_BITS_GAIN  => c_n_gain
    )
    PORT MAP(
        x    => s_amplitude,
        gain => gain_in,
        y    => s_gained
    );

    -- Entity offset expects input with same number of bits (N=12) as value. So
    -- zero extend to the left (for signed conversation) and add three lsb.
    s_offset <= '0' & SIGNED(offset_in) & "000";

    offset1 : offset
    GENERIC MAP(
        N_BITS    => c_n_value,
        VALUE_MAX => 2 ** (c_n_value - 1) - 1, -- full range
        VALUE_MIN => - 2 ** (c_n_value - 1)    -- full range
    )
    PORT MAP(
        x      => s_gained,
        offset => s_offset,
        y      => s_offsetted
    );

    -- =========================================================================
    -- Purpose: Output value register
    -- Type:    sequential
    -- Inputs:  clock, n_reset, s_value
    -- Outputs: value
    -- =========================================================================
    value_reg : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_value <= (OTHERS => '0');
            ELSE
                s_value <= s_offsetted;
            END IF;
        END IF;
    END PROCESS value_reg;

    -- Output register value.
    value <= s_value;

END ARCHITECTURE no_target_specific;
