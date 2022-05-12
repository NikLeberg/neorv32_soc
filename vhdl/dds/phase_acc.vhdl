-- =============================================================================
-- File:                    phase_acc.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  phase_acc
--
-- Description:             Phase accumulator for Direct Digital Synthesis.
--                          Accumulates on every clock the value of the delta
--                          phase (or as others name it: tuning word) to the
--                          phase. So in essence this is an up counter with
--                          variable step size.
--
-- Note:                    The bit width of the phase determines the frequency
--                          accuracy of the DDS. Commonly the width is somewhere
--                          between 24 - 32 bits. The frequency resolution can
--                          be calculated as follows: delta_f = f_clock / 2^N.
--                          For N = 32 and f_clock = 50 MHz this is 11.6 mHz.
--                          Only integer multiples of this frequency resolution
--                          can be represented.
--
-- Changes:                 0.1, 2022-05-07, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY phase_acc IS
    GENERIC (
        N_BITS : POSITIVE := 32 -- width of phase accumulator, see note
    );
    PORT (
        clock, n_reset : IN STD_LOGIC;

        delta_phase : IN UNSIGNED(N_BITS - 1 DOWNTO 0);
        phase       : OUT UNSIGNED(N_BITS - 1 DOWNTO 0)
    );
END ENTITY phase_acc;

ARCHITECTURE no_target_specific OF phase_acc IS
    SIGNAL s_phase : UNSIGNED(N_BITS - 1 DOWNTO 0);
BEGIN

    -- =========================================================================
    -- Purpose: Phase accumulator
    -- Type:    sequential
    -- Inputs:  clock, n_reset, delta_phase
    -- Outputs: s_phase
    -- =========================================================================
    phase_acc : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_phase <= (OTHERS => '0');
            ELSE
                s_phase <= s_phase + delta_phase;
            END IF;
        END IF;
    END PROCESS phase_acc;

    -- =========================================================================
    -- Purpose: Output of phase
    -- Type:    combinational
    -- Inputs:  s_phase
    -- Outputs: phase
    -- =========================================================================
    phase <= s_phase;

END ARCHITECTURE no_target_specific;
