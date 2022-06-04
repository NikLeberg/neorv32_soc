-- =============================================================================
-- File:                    fixed_pwm_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  fixed_pwm_tb
--
-- Description:             Testbench for fixed_pwm entity. Checks if the output
--                          pwm is correctly formed.
--
-- Changes:                 0.1, 2022-06-05, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY fixed_pwm_tb IS
    -- Testbench needs no ports.
END ENTITY fixed_pwm_tb;

ARCHITECTURE simulation OF fixed_pwm_tb IS
    -- Component definition for device under test.
    COMPONENT fixed_pwm
        GENERIC (
            N_BITS     : POSITIVE;
            COUNT_MAX  : POSITIVE;
            COUNT_HIGH : NATURAL;
            COUNT_LOW  : NATURAL
        );
        PORT (
            clock, n_reset : IN STD_LOGIC;

            pwm : OUT STD_LOGIC
        );
    END COMPONENT fixed_pwm;
    -- Signals for sequential DUTs.
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    -- Signals for connecting to the DUT.
    SIGNAL s_pwm : STD_LOGIC := '0';

BEGIN
    -- Instantiate the device under test.
    dut : fixed_pwm
    GENERIC MAP(
        -- PWM that counts to 9 (0 ... 9), is high for two clocks and then
        -- inactive for the rest.
        N_BITS     => 4,
        COUNT_MAX  => 9,
        COUNT_HIGH => 0,
        COUNT_LOW  => 2
    )
    PORT MAP(
        clock   => s_clock,
        n_reset => s_n_reset,
        pwm     => s_pwm
    );

    -- Clock with 50 MHz.
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 10 ns;

    -- Power on reset the DUT, lasts two clock cycles.
    s_n_reset <= '0', '1' AFTER 40 ns;

    test : PROCESS IS
        -- Procedure that checks the pwm output for the correct form.
        PROCEDURE check (
            -- Sequence of bits that is expected from the DUT.
            CONSTANT x : STD_LOGIC_VECTOR(19 DOWNTO 0)
        ) IS
        BEGIN
            FOR i IN 19 DOWNTO 0 LOOP
                WAIT FOR 20 ns;
                ASSERT s_pwm = x(i)
                REPORT "Expected pwm value after " & INTEGER'image(20 - i) &
                    " clocks to be " & STD_LOGIC'image(x(i)) & "."
                    SEVERITY failure;
            END LOOP;
        END PROCEDURE check;
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(s_n_reset);

        -- Check the pwn output is exactly formed as defined by generics.
        check("11000000001100000000");
        check("11000000001100000000");

        -- Report successful test.
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
