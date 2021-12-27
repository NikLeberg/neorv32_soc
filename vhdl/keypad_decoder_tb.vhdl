-- =============================================================================
-- File:                    keypad_decoder_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  keypad_decoder_tb
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
USE ieee.numeric_std.ALL;
USE std.env.stop;

LIBRARY work;
USE work.datatypes.ALL;

ENTITY keypad_decoder_tb IS
    -- testbench needs no ports
END ENTITY keypad_decoder_tb;

ARCHITECTURE simulation OF keypad_decoder_tb IS
    -- component definition for device under test
    COMPONENT keypad_decoder
        PORT (
            key     : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            pressed : IN STD_LOGIC;

            number   : OUT UNSIGNED(3 DOWNTO 0);
            operator : OUT operator_type
        );
    END COMPONENT keypad_decoder;
    -- signals for connecting to the DUT
    SIGNAL s_key : STD_LOGIC_VECTOR(3 DOWNTO 0) := x"0";
    SIGNAL s_pressed : STD_LOGIC := '0';
    SIGNAL s_number : UNSIGNED(3 DOWNTO 0);
    SIGNAL s_operator : operator_type;
BEGIN
    -- instantiate the device under test
    dut : keypad_decoder
    PORT MAP(
        key      => s_key,
        pressed  => s_pressed,
        number   => s_number,
        operator => s_operator
    );

    test : PROCESS IS
    BEGIN
        s_pressed <= '1';

        -- test the decoding of a few numerical keys
        s_key <= x"0";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(0, 4) AND s_operator = NOTHING
        REPORT "Expected number 0." SEVERITY failure;
        s_key <= x"1";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(1, 4) AND s_operator = NOTHING
        REPORT "Expected number 1." SEVERITY failure;
        s_key <= x"2";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(2, 4) AND s_operator = NOTHING
        REPORT "Expected number 2." SEVERITY failure;
        s_key <= x"4";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(4, 4) AND s_operator = NOTHING
        REPORT "Expected number 4." SEVERITY failure;
        s_key <= x"7";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(7, 4) AND s_operator = NOTHING
        REPORT "Expected number 7." SEVERITY failure;
        s_key <= x"9";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(9, 4) AND s_operator = NOTHING
        REPORT "Expected number 9." SEVERITY failure;

        -- test the decoding of operators
        s_key <= x"A";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(0, 4) AND s_operator = ADD
        REPORT "Expected operator ADD." SEVERITY failure;
        s_key <= x"B";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(0, 4) AND s_operator = SUBTRACT
        REPORT "Expected operator SUBTRACT." SEVERITY failure;
        s_key <= x"C";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(0, 4) AND s_operator = MULTIPLY
        REPORT "Expected operator MULTIPLY." SEVERITY failure;
        s_key <= x"D";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(0, 4) AND s_operator = DIVIDE
        REPORT "Expected operator DIVIDE." SEVERITY failure;
        s_key <= x"E";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(0, 4) AND s_operator = ENTER
        REPORT "Expected operator ENTER." SEVERITY failure;
        s_key <= x"F";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(0, 4) AND s_operator = CHANGE_SIGN
        REPORT "Expected operator CHANGE_SIGN." SEVERITY failure;

        -- test that no conversation is done when nothing is pressed
        s_pressed <= '0';
        s_key <= x"2";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(0, 4) AND s_operator = NOTHING
        REPORT "Expected no number and no operator." SEVERITY failure;
        s_key <= x"7";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(0, 4) AND s_operator = NOTHING
        REPORT "Expected no number and no operator." SEVERITY failure;
        s_key <= x"B";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(0, 4) AND s_operator = NOTHING
        REPORT "Expected no number and no operator." SEVERITY failure;
        s_key <= x"F";
        WAIT FOR 10 ns;
        ASSERT s_number = to_unsigned(0, 4) AND s_operator = NOTHING
        REPORT "Expected no number and no operator." SEVERITY failure;

        -- report successful test
        REPORT "Test OK";
        stop;
    END PROCESS test;
END ARCHITECTURE simulation;
