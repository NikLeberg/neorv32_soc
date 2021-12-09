-- =============================================================================
-- Authors:					Niklaus Leuenberger <leuen4@bfh.ch>
--                          Reusser Adrian <reusa1@bfh.ch>
--
-- Entity:					example
--
-- Description:             Template file for vhdl entities and their
--                          architecture. Here should be described what the
--                          entity is implementing and how.
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
    SIGNAL s_and : STD_LOGIC; -- signal description
BEGIN
    -- process description
    and_1 : PROCESS (a, b) IS
    BEGIN
        s_and <= a AND b;
    END PROCESS and_1;

    y <= s_and;

END ARCHITECTURE no_target_specific;
