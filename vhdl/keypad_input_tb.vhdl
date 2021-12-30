-- =============================================================================
-- File:                    keypad_input_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  keypad_input_tb
--
-- Description:             Testbench for keypad_input entity. Tests that the
--                          fsm implementation detects continuous key presses as
--                          one key press.
--
-- Changes:                 0.1, 2021-12-27, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE std.env.finish;

ENTITY keypad_input_tb IS
    -- testbench needs no ports
END ENTITY keypad_input_tb;

ARCHITECTURE simulation OF keypad_input_tb IS
    -- component definition for device under test
    COMPONENT keypad_input
        PORT (
            clock   : IN STD_LOGIC;
            n_reset : IN STD_LOGIC;

            key     : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            pressed : IN STD_LOGIC;

            new_key     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            new_pressed : OUT STD_LOGIC
        );
    END COMPONENT keypad_input;
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
    dut : keypad_input
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

        -- test the detection of new presses
        s_pressed <= '1';
        s_key <= x"1";
        WAIT FOR 10 ns;
        s_pressed <= '0';
        s_key <= x"0";
        WAIT FOR 10 ns;
        ASSERT s_new_key = x"1" AND s_new_pressed = '1'
        REPORT "Did not detect key 1 press." SEVERITY failure;

        -- test the memory of last pressed key
        WAIT FOR 20 ns;
        ASSERT s_new_key = x"1"
        REPORT "Did not remember key 1." SEVERITY failure;
        WAIT FOR 20 ns;
        ASSERT s_new_key = x"1"
        REPORT "Did not remember key 1." SEVERITY failure;

        -- test that repeated key press of same key is not detected
        s_pressed <= '1';
        s_key <= x"1";
        WAIT FOR 10 ns;
        s_pressed <= '0';
        s_key <= x"0";
        WAIT FOR 10 ns;
        ASSERT s_new_key = x"1" AND s_new_pressed = '0'
        REPORT "Should not have detected repeated key 1 press." SEVERITY failure;

        -- test the detection of a second new press
        s_pressed <= '1';
        s_key <= x"2";
        WAIT FOR 10 ns;
        s_pressed <= '0';
        s_key <= x"0";
        WAIT FOR 10 ns;
        ASSERT s_new_key = x"2" AND s_new_pressed = '1'
        REPORT "Did not detect key 2 press." SEVERITY failure;

        -- report successful test
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
