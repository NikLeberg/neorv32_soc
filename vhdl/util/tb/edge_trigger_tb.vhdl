-- =============================================================================
-- File:                    edge_trigger_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  edge_trigger_tb
--
-- Description:             Testbench for edge_trigger entity. Checks if the
--                          input is correctly edge detected.
--
-- Changes:                 0.1, 2022-06-26, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY edge_trigger_tb IS
    -- Testbench needs no ports.
END ENTITY edge_trigger_tb;

ARCHITECTURE simulation OF edge_trigger_tb IS
    -- Component definition for device under test.
    COMPONENT edge_trigger
        PORT (
            clock, n_reset : IN STD_LOGIC;

            x : IN STD_LOGIC;
            y : OUT STD_LOGIC
        );
    END COMPONENT edge_trigger;
    -- Signals for sequential DUTs.
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    -- Signals for connecting to the DUT.
    SIGNAL s_x, s_y : STD_LOGIC := '0';
BEGIN
    -- Instantiate the device under test.
    dut : edge_trigger
    PORT MAP(
        clock   => s_clock,
        n_reset => s_n_reset,
        x       => s_x,
        y       => s_y
    );

    -- Clock with 50 MHz.
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 10 ns;

    -- Power on reset the DUT, lasts two clock cycles.
    s_n_reset <= '0', '1' AFTER 40 ns;

    test : PROCESS IS
        -- Procedure that generates stimuli for the given sequence. Response
        -- from DUT is checked after each clock for correctness.
        PROCEDURE check (
            -- Sequence of bits to stimulate the DUT with.
            CONSTANT x : STD_LOGIC_VECTOR(9 DOWNTO 0);
            -- Expected output at after each step of the sequence.
            CONSTANT y : STD_LOGIC_VECTOR(9 DOWNTO 0)
        ) IS
        BEGIN
            FOR i IN 9 DOWNTO 0 LOOP
                s_x <= x(i);
                WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
                ASSERT s_y = y(i)
                REPORT "Expected y to be " & STD_LOGIC'image(y(i)) &
                    " but got " & STD_LOGIC'image(s_y) & ". " &
                    "Was in sequence at step " & INTEGER'image(y'HIGH - i) & "."
                    SEVERITY failure;
                WAIT UNTIL rising_edge(s_clock);
            END LOOP;
            -- Restore initial state by setting input to low for a clock.
            s_x <= '0';
            WAIT UNTIL rising_edge(s_clock);
        END PROCEDURE check;
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(s_n_reset);

        check("0000000000", "0000000000");
        check("1111111111", "1000000000");
        check("1110000000", "1000000000");
        check("1110111000", "1000100000");
        check("1010101010", "1010101010");

        -- Report successful test.
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
