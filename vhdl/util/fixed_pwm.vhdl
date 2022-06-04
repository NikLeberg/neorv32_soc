-- =============================================================================
-- File:                    fixed_pwm.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  fixed_pwm
--
-- Description:             Generator for a PWM of a generically configurable
--                          signal form. The system clock is used to drive a
--                          simple counter. Generic COUNT_MAX defines frequency
--                          of pwm. f = f_sys / COUNT_MAX. Generics COUNT_HIGH
--                          and COUNT_LOW define duty-cycle of pwm. If low is
--                          set to 0 and high to half the max count, a
--                          duty-cycle of 50 % is set.
--
-- Changes:                 0.1, 2022-06-05, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY fixed_pwm IS
    GENERIC (
        N_BITS     : POSITIVE := 7;  -- width of counter value
        COUNT_MAX  : POSITIVE := 99; -- maximum counter value
        COUNT_HIGH : NATURAL  := 0;  -- value at which output becomes 1
        COUNT_LOW  : NATURAL  := 50  -- value at which output becomes 0
    );
    PORT (
        clock, n_reset : IN STD_LOGIC;

        pwm : OUT STD_LOGIC -- pwm signal
    );
END ENTITY fixed_pwm;

ARCHITECTURE no_target_specific OF fixed_pwm IS
    -- Signals and constants for counter.
    SIGNAL s_count : UNSIGNED(N_BITS - 1 DOWNTO 0);
    CONSTANT c_count_max : UNSIGNED(N_BITS - 1 DOWNTO 0) := to_unsigned(COUNT_MAX, N_BITS);
    CONSTANT c_count_high : UNSIGNED(N_BITS - 1 DOWNTO 0) := to_unsigned(COUNT_HIGH, N_BITS);
    CONSTANT c_count_low : UNSIGNED(N_BITS - 1 DOWNTO 0) := to_unsigned(COUNT_LOW, N_BITS);
BEGIN

    -- =========================================================================
    -- Purpose: Count up to COUNT_MAX and then reset to 0.
    -- Type:    sequential
    -- Inputs:  clock, n_reset
    -- Outputs: s_count
    -- =========================================================================
    counter : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_count <= (OTHERS => '0');
            ELSE
                IF (s_count < c_count_max) THEN
                    s_count <= s_count + 1;
                ELSE
                    s_count <= (OTHERS => '0');
                END IF;
            END IF;
        END IF;
    END PROCESS counter;

    -- =========================================================================
    -- Purpose: Logic for setting and reseting pwm output at specified values.
    -- Type:    sequential
    -- Inputs:  clock, s_count
    -- Outputs: pwm
    -- =========================================================================
    pwm_output : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                pwm <= '0';
            ELSE
                IF (s_count = c_count_high) THEN
                    pwm <= '1';
                END IF;
                IF (s_count = c_count_low) THEN
                    pwm <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS pwm_output;

END ARCHITECTURE no_target_specific;
