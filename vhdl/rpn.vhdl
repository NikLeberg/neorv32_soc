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
USE work.datatypes.ALL;

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
    -- define component keypad
    COMPONENT keypad
        PORT (
            clock    : IN STD_LOGIC;
            n_reset  : IN STD_LOGIC;
            rows     : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            columns  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            number   : OUT UNSIGNED(3 DOWNTO 0);
            operator : OUT operator_type;
            pressed  : OUT STD_LOGIC
        );
    END COMPONENT keypad;

    SIGNAL s_presses : UNSIGNED(3 DOWNTO 0) := to_unsigned(0, 4);
    SIGNAL s_new_pressed : STD_LOGIC;
    SIGNAL s_number : UNSIGNED(3 DOWNTO 0) := to_unsigned(0, 4);
BEGIN
    -- instantiate keypad
    keypad_instance : keypad
    PORT MAP(
        clock    => clock,
        n_reset  => n_reset,
        rows     => rows,
        columns  => columns,
        number   => s_number,
        operator => OPEN,
        pressed  => s_new_pressed
    );

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
    pressed <= s_new_pressed;
    key <= STD_LOGIC_VECTOR(s_number);

END ARCHITECTURE no_target_specific;
