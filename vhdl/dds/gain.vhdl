-- =============================================================================
-- File:                    gain.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  gain
--
-- Description:             Gain for Direct Digital Synthesis. Multiplies the
--                          input signal with a variable. So that y = x * gain.
--                          Result of multiplication of two numbers with N bits
--                          has a width of 2*N bits. For this DDS gain only the
--                          upper N MSB bits of the result are used. This
--                          essentially allows for the input value to use its
--                          full value range and precision before this gain
--                          entity then scales it down. The effectively applied
--                          gain is max. 1 and min. 1 / 2^N_GAIN.
--
-- Note:                    Synthesizer should be inferring a multiplier.
--                          Quartus Prime states successful inferring in a log
--                          message like so: "Info (278001): Inferred 1
--                          megafunctions from design logic" and "Info (278003):
--                          Inferred multiplier megafunction ("lpm_mult") from
--                          the following logic: <>"
--
-- Changes:                 0.1, 2022-05-20, leuen4
--                              initial implementation
--                          0.2, 2022-05-23, leneu4
--                              add note on multiplier inferring
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY gain IS
    GENERIC (
        N_BITS_VALUE : POSITIVE := 10; -- width of data in-/output
        N_BITS_GAIN  : POSITIVE := 7   -- bits of gain input
    );
    PORT (
        x    : IN SIGNED(N_BITS_VALUE - 1 DOWNTO 0);  -- input value
        gain : IN UNSIGNED(N_BITS_GAIN - 1 DOWNTO 0); -- gain to multiply with
        y    : OUT SIGNED(N_BITS_VALUE - 1 DOWNTO 0)  -- output with applied gain
    );
END ENTITY gain;

ARCHITECTURE no_target_specific OF gain IS
    SIGNAL s_intermediate : signed(N_BITS_VALUE + N_BITS_GAIN DOWNTO 0);
BEGIN

    -- =========================================================================
    -- Purpose: Multiply value by gain.
    -- Type:    combinational
    -- Inputs:  x, gain
    -- Outputs: s_intermediate, y
    -- =========================================================================
    -- Store result of multiplication in an intermediate signal. An additional
    -- bit is needed to cast unsigned gain to signed value that is always
    -- positive (no sign extend). Only use top N MSB bits as output value.
    s_intermediate <= x * SIGNED('0' & gain);
    y <= s_intermediate(N_BITS_VALUE + N_BITS_GAIN - 1 DOWNTO N_BITS_GAIN);

END ARCHITECTURE no_target_specific;
