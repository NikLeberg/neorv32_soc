-- =============================================================================
-- File:                    delta_phase.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  delta_phase
--
-- Description:             Frequency to delta_phase (tuning word) conversation
--                          for Direct Digital Synthesis. Depending on the
--                          system frequency and the desired DDS frequency, this
--                          entity calculates the necessary phase delta that
--                          needs to be added every clock to the phase
--                          accumulator to get the desired frequency. For this
--                          the desired frequency in Hz as a number is
--                          multiplied with a constant that is determined based
--                          on system clock and phase bit width. As a
--                          multiplication with a constant can be represented in
--                          an addition of the idividual multiples of 2 e.g.
--                          7 * 24 = 7 * 16 + 7 * 8 and a multiplication with a
--                          power of 2 is just a shift, this makes for an easy
--                          algorithm.
--
-- Note:                    Entity is implemented in an non generic way. The
--                          constant with which the frequency must be multiplied
--                          can be calculated with: round(2^N / f_clock). For
--                          N = 32 and f_clock = 50 MHz this equals 86. The
--                          multiplication with this constant is then
--                          implemented in the described algorithm with the
--                          minimal set of adders, 3 in total, in a tree-like
--                          structure for maximum speed.
--                          f*86 = f*64 + f*16 + f*4 + f*2
--                               = (f<<6 + f<<4) + (f<<2 + f<<1)
--
-- Changes:                 0.1, 2022-05-12, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

ENTITY delta_phase IS
    PORT (
        f           : IN UNSIGNED(32 - 1 DOWNTO 0); -- desired frequency [Hz]
        delta_phase : OUT UNSIGNED(32 - 1 DOWNTO 0) -- delta for accumulator
    );
END ENTITY delta_phase;

ARCHITECTURE no_target_specific OF delta_phase IS
    -- Intermediate results of shifted input value.
    SIGNAL s_f_shift_6, s_f_shift_4, s_f_shift_2, s_f_shift_1 : UNSIGNED(32 - 1 DOWNTO 0);
    -- Intermediate results of addition of the shifted values.
    SIGNAL s_intermediate_1, s_intermediate_2 : UNSIGNED(32 - 1 DOWNTO 0);
BEGIN

    -- =========================================================================
    -- Purpose: Intermediate addition f*64 + f*16 = f<<6 + f<<4
    -- Type:    combinational
    -- Inputs:  f
    -- Outputs: s_intermediate_1
    -- =========================================================================
    s_f_shift_6 <= f(f'HIGH - 6 DOWNTO 0) & "000000";
    s_f_shift_4 <= f(f'HIGH - 4 DOWNTO 0) & "0000";
    s_intermediate_1 <= s_f_shift_6 + s_f_shift_4;

    -- =========================================================================
    -- Purpose: Intermediate addition f*4 + f*2 = f<<2 + f<<1
    -- Type:    combinational
    -- Inputs:  f
    -- Outputs: s_intermediate_2
    -- =========================================================================
    s_f_shift_2 <= f(f'HIGH - 2 DOWNTO 0) & "00";
    s_f_shift_1 <= f(f'HIGH - 1 DOWNTO 0) & '0';
    s_intermediate_2 <= s_f_shift_2 + s_f_shift_1;

    -- =========================================================================
    -- Purpose: Final addition
    -- Type:    combinational
    -- Inputs:  s_intermediate_1, s_intermediate_2
    -- Outputs: delta_phase
    -- =========================================================================
    delta_phase <= s_intermediate_1 + s_intermediate_2;

END ARCHITECTURE no_target_specific;
