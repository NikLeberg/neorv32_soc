-- =============================================================================
-- File:                    inc_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  inc_tb
--
-- Description:             Testbench for inc entity. Produces some test vectors
--                          of A/B signals and checks if the DUT detects
--                          increments correctly. 
--
-- Changes:                 0.1, 2022-06-08, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY inc_tb IS
    -- Testbench needs no ports.
END ENTITY inc_tb;

ARCHITECTURE simulation OF inc_tb IS
    -- Component definition for device under test.
    COMPONENT inc
        PORT (
            clock, n_reset : IN STD_LOGIC;

            a, b     : IN STD_LOGIC;
            pos, neg : OUT STD_LOGIC
        );
    END COMPONENT inc;
    -- Signals for sequential DUTs.
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    -- Signals for connecting to the DUT.
    SIGNAL s_a, s_b, s_pos, s_neg : STD_LOGIC := '0';
    SIGNAL pos_dbg, neg_dbg : STD_LOGIC := '0';
BEGIN
    -- Instantiate the device under test.
    dut : inc
    PORT MAP(
        clock   => s_clock,
        n_reset => s_n_reset,
        a       => s_a,
        b       => s_b,
        pos     => s_pos,
        neg     => s_neg
    );

    -- Clock with 50 MHz.
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 10 ns;

    -- Power on reset the DUT, lasts two clock cycles.
    -- s_n_reset <= '0', '1' AFTER 40 ns;

    test : PROCESS IS
        -- Procedure that generates stimuli (A/B values) for the DUT. The
        -- returned pos/neg pulses are compared with the expected value.
        PROCEDURE check (
            -- a/b: Vector of signals that the DUT sees clock by clock.
            -- pos/neg: Vector of expected signals from the DUT one clock later.
            CONSTANT a, b, pos, neg : STD_LOGIC_VECTOR(19 DOWNTO 0)
        ) IS
        BEGIN
            -- First reset the DUT i.e. its internal state machine.
            s_n_reset <= '0';
            WAIT FOR 40 ns;
            s_n_reset <= '1';
            -- Check for 20 clock cycles.
            FOR i IN a'HIGH DOWNTO 0 LOOP
                -- Set DUT inputs.
                s_a <= a(i);
                s_b <= b(i);
                -- Wait one clock cycle and a bit more for combinatorics.
                WAIT UNTIL rising_edge(s_clock);
                WAIT FOR 1 ns;
                -- Check for expected output.
                pos_dbg <= pos(i);
                neg_dbg <= neg(i);
                ASSERT pos(i) = s_pos
                REPORT "Expected pos signal of " & STD_LOGIC'image(pos(i)) &
                    " but got " & STD_LOGIC'image(s_pos) & "."
                    SEVERITY failure;
                ASSERT neg(i) = s_neg
                REPORT "Expected neg signal of " & STD_LOGIC'image(neg(i)) &
                    " but got " & STD_LOGIC'image(s_neg) & "."
                    SEVERITY failure;
            END LOOP;
        END PROCEDURE check;
    BEGIN
        -- Note: Signals a/b are active low!

        -- No input = No output
        check("11111111111111111111", "11111111111111111111", "00000000000000000000", "00000000000000000000");
        -- Constant a input = No output
        check("00000000000000000000", "11111111111111111111", "00000000000000000000", "00000000000000000000");
        -- Constant b input = No output
        check("11111111111111111111", "00000000000000000000", "00000000000000000000", "00000000000000000000");
        -- Constant a & b input = No output
        check("00000000000000000000", "00000000000000000000", "00000000000000000000", "00000000000000000000");
        -- Short pulses on a = No output
        check("01010101010101010101", "11111111111111111111", "00000000000000000000", "00000000000000000000");
        -- Short pulses on b = No output
        check("11111111111111111111", "01010101010101010101", "00000000000000000000", "00000000000000000000");

        -- One valid fast cycle for a positive pulse.
        check("10011111111111111111", "11001111111111111111", "00001000000000000000", "00000000000000000000");
        -- One valid medium speed cycle for a positive pulse.
        check("11100000011111111111", "11111100000011111111", "00000000000010000000", "00000000000000000000");
        -- One valid slow cycle for a positive pulse.
        check("11100000000000011111", "11111100000000000011", "00000000000000000010", "00000000000000000000");

        -- One valid fast cycle for a negative pulse.
        check("11001111111111111111", "10011111111111111111", "00000000000000000000", "00001000000000000000");
        -- One valid medium speed cycle for a negative pulse.
        check("11111100000011111111", "11100000011111111111", "00000000000000000000", "00000000000010000000");
        -- One valid slow cycle for a negative pulse.
        check("11111100000000000011", "11100000000000011111", "00000000000000000000", "00000000000000000010");

        -- Multiple valid fast cycles for positive pulses.
        --> is too fast for internal state machine, only every second pulse
        check("10011001100110011001", "11001100110011001100", "00001000000010000000", "00000000000000000000");
        -- Multiple valid medium speed cycles for positive pulses.
        check("00011100011100011100", "10001110001110001110", "00001000001000001000", "00000000000000000000");

        -- Multiple valid fast cycles for negative pulses.
        --> is too fast for internal state machine, only every second pulse
        check("11001100110011001100", "10011001100110011001", "00000000000000000000", "00001000000010000000");
        -- Multiple valid medium speed cycles for negative pulses.
        check("10001110001110001110", "00011100011100011100", "00000000000000000000", "00001000001000001000");

        -- One positive pulse followed by a negative pulse.
        check("00011111111110001111", "10001111111100011111", "00001000000000000000", "00000000000000001000");

        -- Report successful test.
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
