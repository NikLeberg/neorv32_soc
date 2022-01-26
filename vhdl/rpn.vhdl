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
USE work.stack_pkg.ALL;

ENTITY rpn IS
    PORT (
        -- clock and reset signals
        clock   : IN STD_LOGIC;
        n_reset : IN STD_LOGIC;

        -- hardware interface to the Pmod keyboard
        rows    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        columns : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);

        -- LED matrix (10 rows x 12 columns, index is row * 12 + column)
        led_matrix : OUT STD_LOGIC_VECTOR((10 * 12) - 1 DOWNTO 0);

        -- 7 segment displays (4x [A, B, C, D, E, F, G, DP])
        seven_seg : OUT STD_LOGIC_VECTOR((4 * 8) - 1 DOWNTO 0)
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
    -- define component stack
    COMPONENT stack IS
        GENERIC (
            num_bits : POSITIVE;
            depth    : POSITIVE
        );
        PORT (
            clock     : IN STD_LOGIC;
            n_reset   : IN STD_LOGIC;
            push, pop : IN STD_LOGIC;
            in_value  : IN STD_LOGIC_VECTOR(num_bits - 1 DOWNTO 0);
            stack     : OUT stack_port_type(depth - 1 DOWNTO 0, num_bits - 1 DOWNTO 0)
        );
    END COMPONENT stack;
    -- define component bin_to_bcd
    COMPONENT bin_to_bcd
        GENERIC (
            num_bits : POSITIVE;
            num_bcd  : POSITIVE
        );
        PORT (
            bin : IN SIGNED(num_bits - 1 DOWNTO 0);
            bcd : OUT STD_LOGIC_VECTOR(num_bcd * 4 DOWNTO 0)
        );
    END COMPONENT bin_to_bcd;
    TYPE state_type IS (
        INPUT_NUMBER, PUSH_NEW_TO_STACK,
        MATH, POP_B_FROM_STACK,
        POP_A_FROM_STACK, PUSH_TO_STACK
    );

    SIGNAL s_number : UNSIGNED(3 DOWNTO 0);
    SIGNAL s_pressed : STD_LOGIC;
    SIGNAL s_stack : stack_port_type(10 - 1 DOWNTO 0, 12 - 1 DOWNTO 0);
    SIGNAL s_in : STD_LOGIC_VECTOR(12 - 1 DOWNTO 0);
    SIGNAL s_operator : operator_type;
    SIGNAL s_current_state, s_next_state : state_type;

BEGIN
    -- instantiate keypad
    keypad_instance : keypad
    PORT MAP(
        clock    => clock,
        n_reset  => n_reset,
        rows     => rows,
        columns  => columns,
        number   => s_number,
        operator => s_operator,
        pressed  => s_pressed
    );
    -- instantiate stack
    stack_instance : stack
    GENERIC MAP(
        num_bits => 12,
        depth    => 10
    )
    PORT MAP(
        clock    => clock,
        n_reset  => n_reset,
        push     => s_pressed,
        pop      => '0',
        in_value => s_in,
        stack    => s_stack
    );
    s_in <= STD_LOGIC_VECTOR(resize(s_number, 12));
    -- instantiate bcd converter
    bcd_instance : bin_to_bcd
    GENERIC MAP(
        num_bits => 4,
        num_bcd  => 2
    )
    PORT MAP(
        bin => signed(s_number),
        bcd => led_matrix(8 DOWNTO 0)
    );

    -- output stack on leds
    stack_out_depth : FOR i IN 10 - 1 DOWNTO 1 GENERATE
        stack_out_width : FOR j IN 12 - 1 DOWNTO 0 GENERATE
            led_matrix(i * 12 + j) <= s_stack(i, j);
        END GENERATE;
    END GENERATE;

    state_memory : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_current_state <= INPUT_NUMBER;
            ELSE
                s_current_state <= s_next_state;
            END IF;
        END IF;
    END PROCESS state_memory;

    nsl : PROCESS (s_current_state, s_operator) IS
    BEGIN
        CASE (s_current_state) IS
            WHEN INPUT_NUMBER =>
                IF (s_operator = NOTHING) THEN
                    s_next_state <= INPUT_NUMBER;
                ELSE
                    s_next_state <= PUSH_NEW_TO_STACK;
                END IF;
            WHEN PUSH_NEW_TO_STACK =>
                IF (s_operator = ENTER) THEN
                    s_next_state <= INPUT_NUMBER;
                ELSE
                    s_next_state <= MATH;
                END IF;
            WHEN MATH =>
                IF (s_operator = CHANGE_SIGN) THEN
                    s_next_state <= POP_A_FROM_STACK;
                ELSE
                    s_next_state <= POP_B_FROM_STACK;
                END IF;
            WHEN POP_B_FROM_STACK =>
                s_next_state <= POP_A_FROM_STACK;
            WHEN POP_A_FROM_STACK =>
                s_next_state <= INPUT_NUMBER;
            WHEN OTHERS =>
                s_next_state <= INPUT_NUMBER;
        END CASE;
    END PROCESS nsl;
END ARCHITECTURE no_target_specific;
