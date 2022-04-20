-- =============================================================================
-- File:                    geni.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  geni
--
-- Description:             Toplevel entity for geni function generator
--                          project. For a full explanation see: ../README.md
--
-- Changes:                 0.1, 2022-04-20, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY geni IS
    PORT (
        -- clock and reset signals
        clock   : IN STD_LOGIC;
        n_reset : IN STD_LOGIC;

        -- LED matrix (10 rows x 12 columns, index is row * 12 + column)
        led_matrix : OUT STD_LOGIC_VECTOR((10 * 12) - 1 DOWNTO 0);

        -- 7 segment displays (4x [A, B, C, D, E, F, G, DP])
        seven_seg : OUT STD_LOGIC_VECTOR((4 * 8) - 1 DOWNTO 0)
    );
END ENTITY geni;

ARCHITECTURE no_target_specific OF geni IS
BEGIN

END ARCHITECTURE no_target_specific;
