-- =============================================================================
-- File:                    rpn.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  rpn
--
-- Description:             Toplevel entity for rpn calculator project. For a
--                          full explanation see: ../README.md
--
-- Changes:                 0.1, 2021-12-27, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY rpn IS
    PORT (
        clock   : IN STD_LOGIC;
        n_reset : IN STD_LOGIC;
        rows    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);

        columns     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        key         : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        pressed     : OUT STD_LOGIC;
        press_count : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY rpn;

ARCHITECTURE no_target_specific OF rpn IS
    -- define component keypad_reader
    COMPONENT keypad_reader
        PORT (
            clock   : IN STD_LOGIC;
            n_reset : IN STD_LOGIC;
            rows    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);

            columns : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            key     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            pressed : OUT STD_LOGIC
        );
    END COMPONENT keypad_reader;
    -- define component
    COMPONENT keypad_debounce IS
        PORT (
            clock   : IN STD_LOGIC;
            n_reset : IN STD_LOGIC;

            key     : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            pressed : IN STD_LOGIC;

            new_key     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            new_pressed : OUT STD_LOGIC
        );
    END COMPONENT keypad_debounce;
    -- define signals to interconnect components
    SIGNAL s_key : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL s_pressed : STD_LOGIC;

    SIGNAL s_presses : UNSIGNED(3 DOWNTO 0) := to_unsigned(0, 4);
    SIGNAL s_new_pressed : STD_LOGIC;
BEGIN
    -- instantiate keypad_reader
    reader : keypad_reader
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        rows    => rows,
        columns => columns,
        key     => s_key,
        pressed => s_pressed
    );
    -- instantiate keypad_debounce
    input : keypad_debounce
    PORT MAP(
        clock       => clock,
        n_reset     => n_reset,
        key         => s_key,
        pressed     => s_pressed,
        new_key     => key,
        new_pressed => s_new_pressed
    );
    pressed <= s_new_pressed;

    pro_1 : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_presses <= to_unsigned(0, 4);
            ELSIF (s_new_pressed = '1') THEN
                s_presses <= s_presses + 1;
            END IF;
        END IF;
    END PROCESS pro_1;

    press_count <= STD_LOGIC_VECTOR(s_presses);

END ARCHITECTURE no_target_specific;
