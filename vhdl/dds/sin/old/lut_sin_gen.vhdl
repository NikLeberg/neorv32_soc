-- =============================================================================
-- File:                    lut_sin_gen.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  lut_sin_gen
--
-- Description:             Look up table (LUT) for sine wave in the range of
--                          [0 2*pi] with generic address and value resolution.
--
-- Note:                    Synthesizer should be inferring a synchronous dual-
--                          port RAM that gets used as ROM. Quartus Prime states
--                          successful inferring in a log message like so:
--                          "Info (19000): Inferred 1 megafunctions from design
--                          logic" and "Info (276031): Inferred altsyncram
--                          megafunction from the following design logic <>"
--
-- Changes:                 0.1, 2022-04-30, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

ENTITY lut_sin_gen IS
    GENERIC (
        N_BITS_ADDRESS : POSITIVE := 12;
        N_BITS_VALUE   : POSITIVE := 10
    );
    PORT (
        clock : IN STD_LOGIC;

        addr_a : IN UNSIGNED(N_BITS_ADDRESS - 1 DOWNTO 0); -- LUT line address
        data_a : OUT UNSIGNED(N_BITS_VALUE - 1 DOWNTO 0)   -- LUT value at address
    );
END ENTITY lut_sin_gen;

ARCHITECTURE no_target_specific OF lut_sin_gen IS
    CONSTANT c_max_address : POSITIVE := 2 ** N_BITS_ADDRESS;
    CONSTANT c_max_value : POSITIVE := 2 ** N_BITS_VALUE;

    TYPE lut_sin_type IS ARRAY(c_max_address - 1 DOWNTO 0) OF UNSIGNED(N_BITS_VALUE - 1 DOWNTO 0);

    FUNCTION gen_lut RETURN lut_sin_type IS
        VARIABLE v_lut_sin : lut_sin_type;
        VARIABLE v_sin_real : REAL;
        VARIABLE v_sin_int : INTEGER;
    BEGIN
        FOR n IN c_max_address - 1 DOWNTO 0 LOOP
            v_sin_real := 0.5 * (sin(REAL(n) * 2.0 * MATH_PI / REAL(c_max_address)) + 1.0);
            v_sin_int := INTEGER(round(v_sin_real * (REAL(c_max_value) - 1.0)));
            v_lut_sin(n) := to_unsigned(v_sin_int, N_BITS_VALUE);
        END LOOP;
        RETURN v_lut_sin;
    END FUNCTION gen_lut;

    CONSTANT c_lut_sin_gen : lut_sin_type := gen_lut;
BEGIN

    -- =========================================================================
    -- Purpose: LUT access on port a
    -- Type:    sequential
    -- Inputs:  clock, addr_a
    -- Outputs: data_a
    -- =========================================================================
    port_a : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            data_a <= c_lut_sin_gen(to_integer(addr_a));
        END IF;
    END PROCESS port_a;

    -- -- =========================================================================
    -- -- Purpose: LUT access on port b
    -- -- Type:    sequential
    -- -- Inputs:  clock, addr_b
    -- -- Outputs: data_b
    -- -- =========================================================================
    -- port_b : PROCESS (clock) IS
    -- BEGIN
    --     IF (rising_edge(clock)) THEN
    --         data_b <= c_lut_sin_gen(to_integer(addr_b));
    --     END IF;
    -- END PROCESS port_b;

END ARCHITECTURE no_target_specific;
