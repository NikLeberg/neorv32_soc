-- =============================================================================
-- File:                    keypad.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  keypad
--
-- Description:             Combines the different entities used to interface
--                          with the Pmod keyboard from Digilent into one.
--                          Used entities are: reader, debounce and decoder.
--
-- Changes:                 0.1, 2022-01-01, leuen4
--                              initial version
--                          0.2, 2022-01-06, leuen4
--                              Explain setting of num_bits for debounce.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.datatypes.ALL;

ENTITY keypad IS
    PORT (
        -- clock and reset signals
        clock   : IN STD_LOGIC;
        n_reset : IN STD_LOGIC;

        -- hardware interface to the Pmod keyboard
        rows    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        columns : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);

        -- output signal with the decoded key press
        number   : OUT UNSIGNED(3 DOWNTO 0);
        operator : OUT operator_type;
        pressed  : OUT STD_LOGIC
    );
END ENTITY keypad;

ARCHITECTURE no_target_specific OF keypad IS
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
    -- define component keypad_debounce
    COMPONENT keypad_debounce IS
        GENERIC (
            num_bits : IN POSITIVE
        );
        PORT (
            clock       : IN STD_LOGIC;
            n_reset     : IN STD_LOGIC;
            key         : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            pressed     : IN STD_LOGIC;
            new_key     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            new_pressed : OUT STD_LOGIC
        );
    END COMPONENT keypad_debounce;
    -- define component keypad_decoder
    COMPONENT keypad_decoder
        PORT (
            key      : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            number   : OUT UNSIGNED(3 DOWNTO 0);
            operator : OUT operator_type
        );
    END COMPONENT keypad_decoder;
    -- signals to connect components together
    SIGNAL s_raw_value, s_debounced_value : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL s_raw_pressed : STD_LOGIC;
BEGIN
    -- instantiate keypad_reader
    reader : keypad_reader
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        rows    => rows,
        columns => columns,
        key     => s_raw_value,
        pressed => s_raw_pressed
    );
    -- instantiate keypad_debounce
    debounce : keypad_debounce
    GENERIC MAP(
        -- set width of cooldown delay: 24 bits = 16777215 clocks = 0.2 s
        num_bits => 24
    )
    PORT MAP(
        clock       => clock,
        n_reset     => n_reset,
        key         => s_raw_value,
        pressed     => s_raw_pressed,
        new_key     => s_debounced_value,
        new_pressed => pressed
    );
    -- instantiate keypad_decoder
    decoder : keypad_decoder
    PORT MAP(
        key      => s_debounced_value,
        number   => number,
        operator => operator
    );
END ARCHITECTURE no_target_specific;
