-- =============================================================================
-- File:                    stack_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  stack_tb
--
-- Description:             Testbench for stack entity. Tests that the
--                          implemented stack reacts correctly to the control
--                          signals. The functions of the stack package are also
--                          checked.
--
-- Changes:                 0.1, 2022-01-19, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.stack_pkg.ALL;

ENTITY stack_tb IS
    -- testbench needs no ports
END ENTITY stack_tb;

ARCHITECTURE simulation OF stack_tb IS
    -- component definition for device under test
    COMPONENT stack
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
    -- signals for sequential DUTs
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    CONSTANT c_timeout : TIME := 200 ns;
    -- signals for connecting to the DUT
    CONSTANT c_num_bits : POSITIVE := 8;
    CONSTANT c_depth : POSITIVE := 4;
    SIGNAL s_push, s_pop : STD_LOGIC := '0';
    SIGNAL s_in_value : UNSIGNED(c_num_bits - 1 DOWNTO 0);
    SIGNAL s_stack : stack_port_type(c_depth - 1 DOWNTO 0, c_num_bits - 1 DOWNTO 0);
    SIGNAL s_unsigned : UNSIGNED(c_num_bits - 1 DOWNTO 0);
    SIGNAL s_signed : SIGNED(c_num_bits - 1 DOWNTO 0);
    SIGNAL s_vector : STD_LOGIC_VECTOR(c_num_bits - 1 DOWNTO 0);
BEGIN
    -- instantiate the device under test
    dut : stack
    GENERIC MAP(
        num_bits => c_num_bits,
        depth    => c_depth
    )
    PORT MAP(
        clock    => s_clock,
        n_reset  => s_n_reset,
        push     => s_push,
        pop      => s_pop,
        in_value => STD_LOGIC_VECTOR(s_in_value),
        stack    => s_stack
    );

    -- First check the conversation functions from the stack_pkg package. This
    -- is not really a runtime test but more a check if it compiles.
    s_vector <= stack_at(s_stack, 0);
    s_unsigned <= stack_at(s_stack, 0);
    s_signed <= stack_at(s_stack, 0);

    -- clock with 100 MHz
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 5 ns;

    -- power on reset the DUT
    s_n_reset <= '0', '1' AFTER 20 ns;

    test : PROCESS IS
    BEGIN
        -- wait for power on reset to finish
        WAIT UNTIL rising_edge(s_n_reset);

        -- after reset, whole stack should be zero / empty
        FOR i IN c_depth - 1 DOWNTO 0 LOOP
            ASSERT stack_at(s_stack, i) = to_unsigned(0, c_num_bits)
            REPORT "Expected stack to be empty on startup." SEVERITY failure;
        END LOOP;

        -- push a value onto stack, the stack should now only hold that value
        s_in_value <= to_unsigned(123, c_num_bits);
        s_push <= '1';
        WAIT UNTIL stack_at(s_stack, 0) = to_unsigned(123, c_num_bits) FOR c_timeout;
        s_push <= '0';
        ASSERT stack_at(s_stack, 0) = to_unsigned(123, c_num_bits)
        REPORT "Expected first value of stack to be '123'." SEVERITY failure;
        FOR i IN c_depth - 1 DOWNTO 1 LOOP
            ASSERT stack_at(s_stack, i) = to_unsigned(0, c_num_bits)
            REPORT "Expected stack except the first value to be empty."
                SEVERITY failure;
        END LOOP;

        -- push a second value onto stack, now two values should be on it
        s_in_value <= to_unsigned(42, c_num_bits);
        s_push <= '1';
        WAIT UNTIL stack_at(s_stack, 0) = to_unsigned(42, c_num_bits) FOR c_timeout;
        s_push <= '0';
        ASSERT stack_at(s_stack, 0) = to_unsigned(42, c_num_bits)
        REPORT "Expected first value of stack to be '42'." SEVERITY failure;
        ASSERT stack_at(s_stack, 1) = to_unsigned(123, c_num_bits)
        REPORT "Expected second value of stack to be '123'." SEVERITY failure;
        FOR i IN c_depth - 1 DOWNTO 2 LOOP
            ASSERT stack_at(s_stack, i) = to_unsigned(0, c_num_bits)
            REPORT "Expected stack except the first two values to be empty."
                SEVERITY failure;
        END LOOP;

        -- pop a value, only one value should be left
        s_pop <= '1';
        WAIT UNTIL stack_at(s_stack, 0) = to_unsigned(123, c_num_bits) FOR c_timeout;
        s_pop <= '0';
        ASSERT stack_at(s_stack, 0) = to_unsigned(123, c_num_bits)
        REPORT "Expected first value of stack to be '123'." SEVERITY failure;
        FOR i IN c_depth - 1 DOWNTO 1 LOOP
            ASSERT stack_at(s_stack, i) = to_unsigned(0, c_num_bits)
            REPORT "Expected stack except the first value to be empty."
                SEVERITY failure;
        END LOOP;

        -- pop the last value, stack should be empty again
        s_pop <= '1';
        WAIT UNTIL stack_at(s_stack, 0) = to_unsigned(0, c_num_bits) FOR c_timeout;
        s_pop <= '0';
        FOR i IN c_depth - 1 DOWNTO 0 LOOP
            ASSERT stack_at(s_stack, i) = to_unsigned(0, c_num_bits)
            REPORT "Expected stack to be empty." SEVERITY failure;
        END LOOP;

        -- push several times and check after each push for valid stack data
        s_in_value <= to_unsigned(85, c_num_bits);
        FOR i IN 0 TO c_depth - 1 LOOP
            s_push <= '1';
            WAIT UNTIL stack_at(s_stack, i) = to_unsigned(85, c_num_bits) FOR c_timeout;
            s_push <= '0';
            FOR j IN 0 TO i LOOP
                ASSERT stack_at(s_stack, j) = to_unsigned(85, c_num_bits)
                REPORT "Stack could not be filled all the way." SEVERITY failure;
            END LOOP;
            FOR j IN i + 1 TO c_depth - 1 LOOP
                ASSERT stack_at(s_stack, j) = to_unsigned(0, c_num_bits)
                REPORT "Stack was pushed more than once." SEVERITY failure;
            END LOOP;
        END LOOP;

        -- pop several times and check after each pop for valid stack data
        FOR i IN c_depth - 1 DOWNTO 0 LOOP
            s_pop <= '1';
            WAIT UNTIL stack_at(s_stack, i) /= to_unsigned(85, c_num_bits) FOR c_timeout;
            s_pop <= '0';
            FOR j IN 0 TO i - 1 LOOP
                ASSERT stack_at(s_stack, j) = to_unsigned(85, c_num_bits)
                REPORT "Stack was poped more than once." SEVERITY failure;
            END LOOP;
            FOR j IN i TO c_depth - 1 LOOP
                ASSERT stack_at(s_stack, j) = to_unsigned(0, c_num_bits)
                REPORT "Stack could not be emptied." SEVERITY failure;
            END LOOP;
        END LOOP;

        -- report successful test
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
