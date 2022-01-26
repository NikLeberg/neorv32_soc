-- =============================================================================
-- File:                    number_input_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  number_input_tb
--
-- Description:             Testbench for number_input entity. Tests that
--                          sequentially entered numbers can be read in.
--
-- Changes:                 0.1, 2022-01-26, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY number_input_tb IS
    -- testbench needs no ports
END ENTITY number_input_tb;

ARCHITECTURE simulation OF number_input_tb IS
    -- component definition for device under test
    COMPONENT number_input
        GENERIC (
            num_bits : POSITIVE;
            num_bcd  : POSITIVE
        );
        PORT (
            clock   : IN STD_LOGIC;
            n_reset : IN STD_LOGIC;
            number  : IN UNSIGNED(3 DOWNTO 0);
            pressed : IN STD_LOGIC;
            bin     : OUT SIGNED(num_bits - 1 DOWNTO 0)
        );
    END COMPONENT number_input;
    -- signals for sequential DUTs
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    -- signals for connecting to the DUT
    CONSTANT c_num_bits : POSITIVE := 8;
    CONSTANT c_num_bcd : POSITIVE := 3;
    SIGNAL s_number : UNSIGNED(3 DOWNTO 0) := to_unsigned(0, 4);
    SIGNAL s_pressed : STD_LOGIC := '0';
    SIGNAL s_bin : SIGNED(c_num_bits - 1 DOWNTO 0);
BEGIN
    -- instantiate the device under test
    dut : number_input
    GENERIC MAP(
        num_bits => c_num_bits,
        num_bcd  => c_num_bcd
    )
    PORT MAP(
        clock   => s_clock,
        n_reset => s_n_reset,
        number  => s_number,
        pressed => s_pressed,
        bin     => s_bin
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

        -- press key "1"
        s_number <= to_unsigned(1, 4);
        s_pressed <= '1';
        WAIT UNTIL rising_edge(s_clock);
        WAIT FOR 5 ns;
        s_pressed <= '0';
        ASSERT to_integer(s_bin) = 1
        REPORT "Expected a value of '1' but got " &
            INTEGER'image(to_integer(s_bin)) & "."
            SEVERITY failure;

        -- press key "0"
        s_number <= to_unsigned(0, 4);
        s_pressed <= '1';
        WAIT UNTIL rising_edge(s_clock);
        WAIT FOR 5 ns;
        s_pressed <= '0';
        ASSERT to_integer(s_bin) = 10
        REPORT "Expected a value of '10' but got " &
            INTEGER'image(to_integer(s_bin)) & "."
            SEVERITY failure;

        -- press key "3"
        s_number <= to_unsigned(3, 4);
        s_pressed <= '1';
        WAIT UNTIL rising_edge(s_clock);
        WAIT FOR 5 ns;
        s_pressed <= '0';
        ASSERT to_integer(s_bin) = 103
        REPORT "Expected a value of '103' but got " &
            INTEGER'image(to_integer(s_bin)) & "."
            SEVERITY failure;

        -- press key "4"
        s_number <= to_unsigned(4, 4);
        s_pressed <= '1';
        WAIT UNTIL rising_edge(s_clock);
        WAIT FOR 5 ns;
        s_pressed <= '0';
        ASSERT to_integer(s_bin) = 34
        REPORT "Expected a value of '34' but got " &
            INTEGER'image(to_integer(s_bin)) & "."
            SEVERITY failure;

        -- report successful test
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
