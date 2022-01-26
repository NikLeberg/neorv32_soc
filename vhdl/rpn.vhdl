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
    -- define component number_input
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
    -- define component math
    COMPONENT math
        GENERIC (
            num_bits : POSITIVE
        );
        PORT (
            operator : IN operator_type;
            a, b     : IN SIGNED(num_bits - 1 DOWNTO 0);
            y        : OUT SIGNED(num_bits - 1 DOWNTO 0);
            div_zero : OUT STD_LOGIC
        );
    END COMPONENT math;
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

    -- signals for the keypad
    SIGNAL s_number : UNSIGNED(3 DOWNTO 0);
    SIGNAL s_pressed : STD_LOGIC;
    SIGNAL s_operator : operator_type;
    SIGNAL s_n_key_reset : STD_LOGIC;

    -- signals for the number_input
    SIGNAL s_number_input : SIGNED(10 DOWNTO 0);

    -- signals for the stack
    SIGNAL s_stack : stack_port_type(9 DOWNTO 0, 11 DOWNTO 0);
    SIGNAL s_pop, s_push : STD_LOGIC;
    SIGNAL s_stack_in : STD_LOGIC_VECTOR(11 DOWNTO 0);
    SIGNAL s_stack_a, s_stack_b : STD_LOGIC_VECTOR(11 DOWNTO 0);

    -- signals for the math
    SIGNAL s_a, s_b, s_y : SIGNED(10 DOWNTO 0);

    -- signals for the toplevel
    SIGNAL s_saved_y : SIGNED(10 DOWNTO 0);

    -- rpn fsm
    TYPE state_type IS (
        INPUT_NUMBER, PUSH_NEW_TO_STACK,
        DO_MATH, POP_B_FROM_STACK,
        POP_A_FROM_STACK, PUSH_TO_STACK, CLEAR_OP
    );
    SIGNAL s_current_state, s_next_state : state_type;

BEGIN
    -- instantiate keypad
    keypad_instance : keypad
    PORT MAP(
        clock    => clock,
        n_reset  => s_n_key_reset,
        rows     => rows,
        columns  => columns,
        number   => s_number,
        operator => s_operator,
        pressed  => s_pressed
    );
    -- instantiate number_input
    number_input_instance : number_input
    GENERIC MAP(
        num_bits => 11,
        num_bcd  => 3
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        number  => s_number,
        pressed => s_pressed,
        bin     => s_number_input
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
        push     => s_push,
        pop      => s_pop,
        in_value => s_stack_in,
        stack    => s_stack
    );
    -- instantiate math
    math_instance : math
    GENERIC MAP(
        num_bits => 11
    )
    PORT MAP(
        operator => s_operator,
        a        => s_a,
        b        => s_b,
        y        => s_y,
        div_zero => OPEN
    );
    -- -- instantiate bcd converter
    -- bcd_instance : bin_to_bcd
    -- GENERIC MAP(
    --     num_bits => 4,
    --     num_bcd  => 2
    -- )
    -- PORT MAP(
    --     bin => signed(s_number),
    --     bcd => led_matrix(8 DOWNTO 0)
    -- );

    -- output stack on leds
    stack_out_depth : FOR i IN 9 DOWNTO 0 GENERATE
        stack_out_width : FOR j IN 11 DOWNTO 0 GENERATE
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
                    s_next_state <= CLEAR_OP;
                ELSE
                    s_next_state <= DO_MATH;
                END IF;
            WHEN DO_MATH =>
                IF (s_operator = CHANGE_SIGN) THEN
                    s_next_state <= POP_A_FROM_STACK;
                ELSE
                    s_next_state <= POP_B_FROM_STACK;
                END IF;
            WHEN POP_B_FROM_STACK =>
                s_next_state <= POP_A_FROM_STACK;
            WHEN POP_A_FROM_STACK =>
                s_next_state <= PUSH_TO_STACK;
            WHEN PUSH_TO_STACK =>
                s_next_state <= CLEAR_OP;
            WHEN CLEAR_OP =>
                s_next_state <= INPUT_NUMBER;
            WHEN OTHERS =>
                s_next_state <= INPUT_NUMBER;
        END CASE;
    END PROCESS nsl;

    -- save result of math while we are poping the operands from the stack
    result_memory : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_saved_y <= (OTHERS => '0');
            ELSIF (s_current_state = DO_MATH) THEN
                s_saved_y <= s_y;
            END IF;
        END IF;
    END PROCESS result_memory;

    -- output_logic for math
    s_a <= SIGNED(s_stack_a(10 DOWNTO 0));
    s_b <= SIGNED(s_stack_b(10 DOWNTO 0));

    -- output_logic for stack
    s_pop <=
        '1' WHEN s_current_state = POP_B_FROM_STACK OR s_current_state = POP_A_FROM_STACK ELSE
        '0';
    s_push <=
        '1' WHEN s_current_state = PUSH_NEW_TO_STACK OR s_current_state = PUSH_TO_STACK ELSE
        '0';
    s_stack_in <= '1' & STD_LOGIC_VECTOR(s_saved_y) WHEN s_current_state = PUSH_TO_STACK ELSE
        '1' & STD_LOGIC_VECTOR(s_number_input) WHEN s_current_state = PUSH_NEW_TO_STACK ELSE
        (OTHERS => '0');
    s_stack_a <= stack_at(s_stack, 1);
    s_stack_b <= stack_at(s_stack, 0);

    -- output_logic for keypad
    s_n_key_reset <= '0' WHEN n_reset = '0' OR s_current_state = PUSH_NEW_TO_STACK OR s_current_state = PUSH_TO_STACK ELSE
        '1';
END ARCHITECTURE no_target_specific;
