-- =============================================================================
-- File:                    stack.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  stack
--
-- Description:             Stack e.g. LIFO buffer for value storage.
--                          With push and pop operations new values can be
--                          pushed onto the stack or poped from the stack.
--                          Configurable in depth and width.
--
-- Note:                    To effectively use this entity, one propably also
--                          wants to use the provided stack_pkg package.
--
-- Changes:                 0.1, 2022-01-13, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE work.stack_pkg.ALL;

ENTITY stack IS
    GENERIC (
        -- bit width of stored values
        num_bits : POSITIVE := 4;
        -- depth of the stack / how many values are stored
        depth : POSITIVE := 4
    );
    PORT (
        clock   : IN STD_LOGIC;
        n_reset : IN STD_LOGIC;
        -- control signals
        push, pop : IN STD_LOGIC;
        -- input value to the stack
        in_value : IN STD_LOGIC_VECTOR(num_bits - 1 DOWNTO 0);
        -- Parallel output of the whole stack. To work in VHDL-93 it is defined
        -- as 2D array of STD_LOGIC. Access to individual stored values can be
        -- gained with "stack_at(stack, i)" function from stack_pkg package.
        stack : OUT stack_port_type(depth - 1 DOWNTO 0, num_bits - 1 DOWNTO 0)
    );
END ENTITY stack;

ARCHITECTURE no_target_specific OF stack IS
    TYPE stack_type IS ARRAY(depth - 1 DOWNTO 0) OF STD_LOGIC_VECTOR(num_bits - 1 DOWNTO 0);
    SIGNAL s_stack : stack_type;
BEGIN
    -- =========================================================================
    -- Purpose: Stack register with shift operations
    -- Type:    sequential
    -- Inputs:  clock, n_reset, push, pop, in_value
    -- Outputs: s_stack
    -- =========================================================================
    stack_memory : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                -- reset the whole stack
                s_stack <= (OTHERS => (OTHERS => '0'));
            ELSIF (push = '1') THEN
                -- push / add a value on to stack
                s_stack(depth - 1 DOWNTO 1) <= s_stack(depth - 2 DOWNTO 0);
                s_stack(0) <= in_value;
            ELSIF (pop = '1') THEN
                -- pop / remove a value from stack
                s_stack(depth - 1) <= (OTHERS => '0');
                s_stack(depth - 2 DOWNTO 0) <= s_stack(depth - 1 DOWNTO 1);
            END IF;
        END IF;
    END PROCESS stack_memory;

    -- =========================================================================
    -- Purpose: Output the whole internal stack
    -- Type:    combinational
    -- Inputs:  s_stack
    -- Outputs: stack
    -- =========================================================================
    -- Convert from internal 1D array of STD_LOGIC_VECTOR to port 2D array of
    -- STD_LOGIC by wiring every bit individually.
    stack_out_depth : FOR i IN depth - 1 DOWNTO 0 GENERATE
        stack_out_width : FOR j IN num_bits - 1 DOWNTO 0 GENERATE
            stack(i, j) <= s_stack(i)(j);
        END GENERATE;
    END GENERATE;
END ARCHITECTURE no_target_specific;
