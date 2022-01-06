-- =============================================================================
-- File:                    keypad_debounce_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  keypad_debounce_tb
--
-- Description:             Testbench for keypad_debounce entity. Tests that the
--                          fsm implementation detects rapid key presses as one
--                          key press. Anly after a timeout it is detected as
--                          new press. This is used to debounce the presses.
--
-- Changes:                 0.1, 2021-12-30, leuen4
--                              initial version
--                          0.2, 2022-01-06, leuen4
--                              Counter is no longer set to c_timeout on reset.
--                              First keypress after reset needs no cooldown.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY keypad_debounce_tb IS
    -- testbench needs no ports
END ENTITY keypad_debounce_tb;

ARCHITECTURE simulation OF keypad_debounce_tb IS
    -- component definition for device under test
    COMPONENT keypad_debounce
        GENERIC (
            num_bits : IN POSITIVE
        );
        PORT (
            clock   : IN STD_LOGIC;
            n_reset : IN STD_LOGIC;

            key     : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            pressed : IN STD_LOGIC;

            new_key     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            new_pressed : OUT STD_LOGIC
        );
    END COMPONENT keypad_debounce;
    -- signals for sequential DUTs
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    -- signals for connecting to the DUT
    SIGNAL s_key : STD_LOGIC_VECTOR(3 DOWNTO 0) := x"0";
    SIGNAL s_pressed : STD_LOGIC := '0';
    SIGNAL s_new_key : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL s_new_pressed : STD_LOGIC;
BEGIN
    -- instantiate the device under test
    dut : keypad_debounce
    GENERIC MAP(
        num_bits => 2 -- set timeout to a low value
    )
    PORT MAP(
        clock       => s_clock,
        n_reset     => s_n_reset,
        key         => s_key,
        pressed     => s_pressed,
        new_key     => s_new_key,
        new_pressed => s_new_pressed
    );

    -- clock with 100 MHz
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 5 ns;

    -- power on reset the DUT
    s_n_reset <= '0', '1' AFTER 20 ns;

    test : PROCESS IS
    BEGIN
        -- wait for power on reset to finish
        WAIT UNTIL rising_edge(s_n_reset);

        -- Counter start with a value of 0 so the cooldown is already reached
        -- and allows for keys to be pressed.
        s_pressed <= '1';
        s_key <= x"1";
        WAIT FOR 10 ns;
        s_pressed <= '0';
        s_key <= x"0";
        WAIT FOR 10 ns;
        ASSERT s_new_key = x"1" AND s_new_pressed = '1'
        REPORT "Did not detect key 1 press." SEVERITY failure;

        -- The value of the last pressed key should be held in memory.
        WAIT FOR 20 ns;
        ASSERT s_new_key = x"1"
        REPORT "Did not remember key 1." SEVERITY failure;
        WAIT FOR 20 ns;
        ASSERT s_new_key = x"1"
        REPORT "Did not remember key 1." SEVERITY failure;

        -- Cooldown should be reached already. Press a key and follow it up with
        -- another key press. Only the first should be detected.
        s_pressed <= '1';
        s_key <= x"2";
        WAIT FOR 10 ns;
        s_pressed <= '0';
        s_key <= x"0";
        WAIT FOR 10 ns;
        ASSERT s_new_key = x"2" AND s_new_pressed = '1'
        REPORT "Did not detect key 2 press." SEVERITY failure;
        s_pressed <= '1';
        s_key <= x"3";
        WAIT FOR 10 ns;
        s_pressed <= '0';
        s_key <= x"0";
        WAIT FOR 10 ns;
        ASSERT s_new_key = x"2" AND s_new_pressed = '0'
        REPORT "Expected no new key press." SEVERITY failure;

        -- report successful test
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
