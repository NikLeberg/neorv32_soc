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

        dbg_clock   : OUT STD_LOGIC;
        dbg_n_reset : OUT STD_LOGIC
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
            -- hexadecimal value of pressed key, 0 = 0x0, 1 = 0x1, ..., F = 0xF
            key     : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            pressed : OUT STD_LOGIC
        );
    END COMPONENT keypad_reader;
BEGIN
    -- instantiate keypad_reader
    dut : keypad_reader
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        rows    => rows,
        columns => columns,
        key     => key,
        pressed => OPEN
    );

    -- =========================================================================
    -- Purpose: Debug outputs
    -- Type:    combinational
    -- Inputs:  clock, n_reset
    -- Outputs: dbg_clock, dbg_n_reset
    -- =========================================================================
    dbg_clock <= clock;
    dbg_n_reset <= n_reset;

END ARCHITECTURE no_target_specific;
