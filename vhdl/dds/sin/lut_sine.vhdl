-- =============================================================================
-- File:                    lut_sine.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  lut_sine
--
-- Description:             Look up table (LUT) for sine wave in the range of
--                          [0 pi/2] with generic address and value resolution.
--                          With this first quarter of a sine wave the full wave
--                          can be reconstructed.
--
-- Note #1:                 Even though this entity uses math_real library, in
--                          the synthesized entity no math elements should
--                          appear. This is because the library is only used to
--                          generate the constant LUT values at compile time.
--
-- Note #2:                 Synthesizer should be inferring a synchronous dual-
--                          port RAM that gets used as ROM. Quartus Prime states
--                          successful inferring in a log message like so:
--                          "Info (19000): Inferred 1 megafunctions from design
--                          logic" and "Info (276031): Inferred altsyncram
--                          megafunction from the following design logic <>"
--
-- Changes:                 0.1, 2022-04-30, leuen4
--                              initial implementation
--                          0.2, 2022-05-15, leuen4
--                              Replace LUT value generator (C program) with
--                              automatically computed LUT values at compile
--                              time. Extend with generics for bit widths.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

ENTITY lut_sine IS
    GENERIC (
        -- Address resolution of sine. As only a quarter of a sine is in the LUT
        -- a consuming entity that reconstructs the full sine wave needs two
        -- additional bits of address. Those are not necessary here.
        N_BITS_ADDRESS : POSITIVE := 8;
        -- Value resolution of sine. The sine wave will start at 0 and end after
        -- pi/2 at a value of 2^N - 1. A consumint entity that reconstruct the
        -- full sine wave needs one additional bit for the value. That is not
        -- necessary here.
        N_BITS_VALUE : POSITIVE := 9
    );
    PORT (
        clock : IN STD_LOGIC;

        -- Dual port line addresses into LUT.
        addr_a, addr_b : IN UNSIGNED(N_BITS_ADDRESS - 1 DOWNTO 0);
        -- Dual port data output from LUT.
        data_a, data_b : OUT UNSIGNED(N_BITS_VALUE - 1 DOWNTO 0)
    );
END ENTITY lut_sine;

ARCHITECTURE no_target_specific OF lut_sine IS
    -- Maximum address for the given resolution if the full wave would be saved.
    CONSTANT c_max_address : POSITIVE := 2 ** (N_BITS_ADDRESS + 2);
    -- Address up to pi/2 to which LUT values are saved.
    CONSTANT c_address_pi_2 : POSITIVE := (2 ** N_BITS_ADDRESS) - 1;
    -- Maximum value that can be represented with given value resolution.
    CONSTANT c_max_value : POSITIVE := (2 ** N_BITS_VALUE) - 1;

    TYPE lut_sine_type IS ARRAY(c_address_pi_2 DOWNTO 0) OF UNSIGNED(N_BITS_VALUE - 1 DOWNTO 0);

    -- Function to generate first quarter of sine wave at compile time.
    FUNCTION gen_lut RETURN lut_sine_type IS
        VARIABLE v_lut_sine : lut_sine_type;
        VARIABLE v_sin_real : REAL;
        VARIABLE v_sin_int : INTEGER;
    BEGIN
        FOR n IN c_address_pi_2 DOWNTO 0 LOOP
            v_sin_real := sin(REAL(n) * 2.0 * MATH_PI / REAL(c_max_address));
            v_sin_int := INTEGER(round(v_sin_real * REAL(c_max_value)));
            v_lut_sine(n) := to_unsigned(v_sin_int, N_BITS_VALUE);
        END LOOP;
        RETURN v_lut_sine;
    END FUNCTION gen_lut;

    CONSTANT c_lut_sine : lut_sine_type := gen_lut;
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
            data_a <= c_lut_sine(to_integer(addr_a));
        END IF;
    END PROCESS port_a;

    -- =========================================================================
    -- Purpose: LUT access on port b
    -- Type:    sequential
    -- Inputs:  clock, addr_b
    -- Outputs: data_b
    -- =========================================================================
    port_b : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            data_b <= c_lut_sine(to_integer(addr_b));
        END IF;
    END PROCESS port_b;

END ARCHITECTURE no_target_specific;
