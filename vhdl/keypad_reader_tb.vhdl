-- =============================================================================
-- File:                    keypad_reader_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  keypad_reader_tb
--
-- Description:             Read in the Pmod Keyboard from Digilent over the 16
--                          pin interface of row and column lines. For more,
--                          see: https://digilent.com/reference/pmod/pmodkypd
--
-- Changes:                 0.1, 2021-12-27, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE std.env.stop;

ENTITY keypad_reader_tb IS
    -- testbench needs no ports
END ENTITY keypad_reader_tb;

ARCHITECTURE simulation OF keypad_reader_tb IS
    -- component definition for device under test
    COMPONENT keypad_reader
        PORT (
            clock   : IN STD_LOGIC;
            n_reset : IN STD_LOGIC;
            rows    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);

            columns : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            -- hexadecimal value of pressed key, 0 = 0x0, 1 = 0x1, ..., F = 0xF
            key : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
        );
    END COMPONENT keypad_reader;
    -- signals for connecting to the DUT
    SIGNAL s_clock : STD_LOGIC := '0';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_rows : STD_LOGIC_VECTOR(3 DOWNTO 0) := "1111";
    SIGNAL s_columns : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL s_key : STD_LOGIC_VECTOR(3 DOWNTO 0);
BEGIN
    -- instantiate the device under test
    dut : keypad_reader
    PORT MAP(
        clock   => s_clock,
        n_reset => s_n_reset,
        rows    => s_rows,
        columns => s_columns,
        key     => s_key
    );

    -- clock with 100 MHz
    s_clock <= NOT s_clock AFTER 5 ns;

    -- power on reset the DUT
    s_n_reset <= '0', '1' AFTER 20 ns;

    test : PROCESS IS
    BEGIN
        -- wait for power on reset to finish
        WAIT UNTIL rising_edge(s_n_reset);

        -- test the cyclic activation of columns
        ASSERT s_columns = "1110"
        REPORT "Column 1 is not active." SEVERITY failure;
        WAIT ON s_columns;
        ASSERT s_columns = "1101"
        REPORT "Column 2 is not active." SEVERITY failure;
        WAIT ON s_columns;
        ASSERT s_columns = "1011"
        REPORT "Column 3 is not active." SEVERITY failure;
        WAIT ON s_columns;
        ASSERT s_columns = "0111"
        REPORT "Column 4 is not active." SEVERITY failure;

        -- test the decoding of "1" key
        s_rows <= "1110";
        WAIT UNTIL s_columns = "1110";
        ASSERT s_key = x"1"
        REPORT "Expected key 1 but got " & to_hstring(s_key) & "." SEVERITY failure;

        -- test the decoding of "5" key
        s_rows <= "1101";
        WAIT UNTIL s_columns = "1101";
        ASSERT s_key = x"5"
        REPORT "Expected key 5 but got " & to_hstring(s_key) & "." SEVERITY failure;

        -- report successful test
        REPORT "Test OK";
        stop;
    END PROCESS test;
END ARCHITECTURE simulation;
