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
        a : IN STD_LOGIC;                    -- input description
        b : OUT STD_LOGIC;                   -- output description
        y : OUT STD_LOGIC_VECTOR(7 DOWNTO 0) -- output description
    );
END ENTITY example;

ARCHITECTURE no_target_specific OF example IS
    SIGNAL s_sig : STD_LOGIC; -- signal description
BEGIN
    -- process description
    pro_1 : PROCESS (a) IS
    BEGIN
        b <= a;
    END PROCESS pro_1;

    y <= "00000000";

END ARCHITECTURE no_target_specific;
