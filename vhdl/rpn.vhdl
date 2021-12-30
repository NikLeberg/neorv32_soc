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

ENTITY rpn IS
    PORT (
        clock   : IN STD_LOGIC;
        n_reset : IN STD_LOGIC;
        rows    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);

        columns : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        key     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        pressed : OUT STD_LOGIC
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
    COMPONENT keypad_input IS
        PORT (
            clock   : IN STD_LOGIC;
            n_reset : IN STD_LOGIC;

            key     : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            pressed : IN STD_LOGIC;

            new_key     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            new_pressed : OUT STD_LOGIC
        );
    END COMPONENT keypad_input;
    -- define signals to interconnect components
    SIGNAL s_key : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL s_pressed : STD_LOGIC;
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
    -- instantiate keypad_input
    input : keypad_input
    PORT MAP(
        clock       => clock,
        n_reset     => n_reset,
        key         => s_key,
        pressed     => s_pressed,
        new_key     => key,
        new_pressed => pressed
    );
END ARCHITECTURE no_target_specific;
