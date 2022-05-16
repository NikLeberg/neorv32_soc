-- =============================================================================
-- File:                    lut_sin_old.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  lut_sin_old
--
-- Description:             Look up table (LUT) for sine wave in the range of
--                          [0 2*pi] with 12 bit resolution. Synthesizer should
--                          be inferring a synchronous dual-port RAM that gets
--                          used as ROM.
--
-- Changes:                 0.1, 2022-04-30, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.lut_sin_pkg.ALL;

ENTITY lut_sin_old IS
    PORT (
        clock : IN STD_LOGIC;

        addr_a, addr_b : IN UNSIGNED(9 DOWNTO 0); -- LUT line address
        data_a, data_b : OUT UNSIGNED(9 DOWNTO 0) -- LUT value at address
    );
END ENTITY lut_sin_old;

ARCHITECTURE no_target_specific OF lut_sin_old IS
BEGIN

    -- =========================================================================
    -- Purpose: LUT access on port a
    -- Type:    sequential
    -- Inputs:  clock, addr_a
    -- Outputs: data_a
    -- =========================================================================
    port_a : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            data_a <= c_lut_sin(to_integer(addr_a));
        END IF;
    END PROCESS port_a;

    -- =========================================================================
    -- Purpose: LUT access on port b
    -- Type:    sequential
    -- Inputs:  clock, addr_b
    -- Outputs: data_b
    -- =========================================================================
    port_b : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            data_b <= c_lut_sin(to_integer(addr_b));
        END IF;
    END PROCESS port_b;

END ARCHITECTURE no_target_specific;
