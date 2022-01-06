-- =============================================================================
-- File:                    keypad_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  keypad_tb
--
-- Description:             Testbench for combined keypad entity. Implements a
--                          simple unit test to verify that the entities work
--                          correctly together.
--
-- Changes:                 0.1, 2022-01-06, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.datatypes.ALL;

ENTITY keypad_tb IS
    -- testbench needs no ports
END ENTITY keypad_tb;

ARCHITECTURE simulation OF keypad_tb IS
    -- component definition for device under test
    COMPONENT keypad
        PORT (
            clock   : IN STD_LOGIC;
            n_reset : IN STD_LOGIC;

            rows    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            columns : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);

            number   : OUT UNSIGNED(3 DOWNTO 0);
            operator : OUT operator_type;
            pressed  : OUT STD_LOGIC
        );
    END COMPONENT keypad;
    -- signals and constants for sequential DUTs
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    CONSTANT c_timeout : TIME := 200 ns;
    -- signals for connecting to the DUT
    SIGNAL s_rows : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1111";
    SIGNAL s_columns : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL s_number : UNSIGNED(3 DOWNTO 0);
    SIGNAL s_operator : operator_type;
    SIGNAL s_pressed : STD_LOGIC;
BEGIN
    -- instantiate the device under test
    dut : keypad
    PORT MAP(
        clock    => s_clock,
        n_reset  => s_n_reset,
        rows     => s_rows,
        columns  => s_columns,
        number   => s_number,
        operator => s_operator,
        pressed  => s_pressed
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

        -- after reset, no press should be detected
        ASSERT s_pressed = '0' AND s_operator = NOTHING AND s_number = to_unsigned(0, 4)
        REPORT "Expected no key press." SEVERITY failure;

        -- check if column output is set at some time
        WAIT UNTIL s_columns = "1110" FOR c_timeout;
        ASSERT s_columns = "1110"
        REPORT "Columns output was not asserted." SEVERITY failure;

        -- simulate key "1" press (column = 1110, row = 1110)
        s_rows <= "1110";
        WAIT ON s_columns FOR c_timeout;
        ASSERT s_columns /= "1110"
        REPORT "Column output was not de-asserted." SEVERITY failure;
        s_rows <= "1111";

        -- check if key is detected
        IF s_pressed /= '1' THEN
            WAIT UNTIL s_pressed = '1' FOR c_timeout;
        END IF;
        ASSERT s_pressed = '1'
        REPORT "Expected key press." SEVERITY failure;

        -- check if key is correctly decoded
        WAIT FOR 10 ns; -- combinational logic needs a bit of time
        ASSERT s_operator = NOTHING
        REPORT "Expected operator NOTHING." SEVERITY failure;
        ASSERT s_number = to_unsigned(1, 4)
        REPORT "Expected number 1 but got " & to_hstring(s_number) & "." SEVERITY failure;

        -- check if decoded key is still saved after a few clocks
        FOR i IN 10 DOWNTO 0 LOOP
            WAIT UNTIL rising_edge(s_clock);
        END LOOP;
        ASSERT s_operator = NOTHING
        REPORT "Expected operator NOTHING." SEVERITY failure;
        ASSERT s_number = to_unsigned(1, 4)
        REPORT "Expected number 1 but got " & to_hstring(s_number) & "." SEVERITY failure;

        -- report successful test
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
