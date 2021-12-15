-- =============================================================================
-- File:                    keypad_reader.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  keypad_reader
--
-- Description:             Read in the Pmod Keyboard from Digilent over the 16
--                          pin interface of row and column lines. For more,
--                          see: https://digilent.com/reference/pmod/pmodkypd
--
-- Changes:                 0.1, 2021-12-10, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY keypad_reader IS
    PORT (
        clock  : IN STD_LOGIC;
        reset  : IN STD_LOGIC;
        column : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        row    : IN STD_LOGIC_VECTOR(3 DOWNTO 0);

        pressed : OUT STD_LOGIC; -- 1 if a key was pressed (active for 1 clock)
        -- hexadecimal value of pressed key, 0 = 0x0, 1 = 0x1, ..., F = 0xF
        key : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
    );
END ENTITY keypad_reader;

ARCHITECTURE no_target_specific OF keypad_reader IS
BEGIN
END ARCHITECTURE no_target_specific;
