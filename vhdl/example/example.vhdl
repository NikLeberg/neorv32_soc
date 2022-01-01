-- =============================================================================
-- File:                    example.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--                          Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  example
--
-- Description:             Template file for vhdl entities and their
--                          architecture. Here should be described what the
--                          entity is implementing and how.
--
-- Changes:                 0.1, 2021-12-10, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY example IS
    PORT (
        a : IN STD_LOGIC; -- input description
        b : IN STD_LOGIC; -- input description
        y : OUT STD_LOGIC -- output description
    );
END ENTITY example;

ARCHITECTURE no_target_specific OF example IS

    -- signal description
    SIGNAL s_and : STD_LOGIC;

BEGIN

    -- =========================================================================
    -- Purpose: Example process
    -- Type:    combinational
    -- Inputs:  a, b
    -- Outputs: s_and
    -- =========================================================================
    and_1 : PROCESS (a, b) IS
    BEGIN
        s_and <= a AND b;
    END PROCESS and_1;

    y <= s_and;

END ARCHITECTURE no_target_specific;
