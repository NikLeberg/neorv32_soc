-- =============================================================================
-- File:                    stack_pkg.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Package:                 stack_pkg
--
-- Description:             Definition of globaly available stack data types and
--                          ease of use access functions.
--
-- Changes:                 0.1, 2022-01-14, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE stack_pkg IS
    -- VHDL-93 doesn't allow an array type with unconstrained element size to be
    -- an entity port. But as we'd like to generically configure the depth and
    -- width of the stack we have to trick a bit by using a 2D array of
    -- STD_LOGIC. The second dimension represents the width of the
    -- STD_LOGIC_VECTOR we ought to represent and would have liked to have in
    -- the first place. Source: https://www.mikrocontroller.net/topic/176622
    TYPE stack_port_type IS ARRAY(NATURAL RANGE <>, NATURAL RANGE <>) OF STD_LOGIC;
    -- To migitate the uggly nature of the 2D stack array and also because it
    -- can't be accesed with a range as index, following functions convert a
    -- given index in the stack to the representation we'd like to have.
    FUNCTION stack_at (stack : stack_port_type; CONSTANT i : NATURAL) RETURN STD_LOGIC_VECTOR;
    FUNCTION stack_at (stack : stack_port_type; CONSTANT i : NATURAL) RETURN UNSIGNED;
    FUNCTION stack_at (stack : stack_port_type; CONSTANT i : NATURAL) RETURN SIGNED;
END PACKAGE stack_pkg;

PACKAGE BODY stack_pkg IS
    -- Access the stack at the given index and convert it to std_logic_vector.
    FUNCTION stack_at (stack : stack_port_type; CONSTANT i : NATURAL) RETURN STD_LOGIC_VECTOR IS
        VARIABLE vector : STD_LOGIC_VECTOR(stack'RANGE(2));
    BEGIN
        -- "RANGE(2)" accesses the range of the second dimension of the stack
        -- e.g. the bit width of the std_logic_vector it ought to represent.
        -- Source: http://computer-programming-forum.com/42-vhdl/9413b72566f62a9c.htm
        FOR j IN stack'RANGE(2) LOOP
            vector(j) := stack(i, j);
        END LOOP;
        RETURN vector;
    END FUNCTION;
    -- Access the stack at the given index and convert it to unsigned.
    FUNCTION stack_at (stack : stack_port_type; CONSTANT i : NATURAL) RETURN UNSIGNED IS
        VARIABLE vector : STD_LOGIC_VECTOR(stack'RANGE(2));
    BEGIN
        vector := stack_at(stack, i);
        RETURN unsigned(vector);
    END FUNCTION;
    -- Access the stack at the given index and convert it to signed.
    FUNCTION stack_at (stack : stack_port_type; CONSTANT i : NATURAL) RETURN SIGNED IS
        VARIABLE vector : STD_LOGIC_VECTOR(stack'RANGE(2));
    BEGIN
        vector := stack_at(stack, i);
        RETURN signed(vector);
    END FUNCTION;
END PACKAGE BODY stack_pkg;
