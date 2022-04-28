-- =============================================================================
-- File:                    inc.vhdl
--
-- Authors:                 Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  inc
--
-- Description:             Detects the direction in which the encoder shaft of
--                          the Digilent PmodENC is turned. Input signals are
--                          expected to be already free of hazards and
--                          debounced. Output pulses are active for one clock
--                          cycle. Hardware reference:
--                          https://digilent.com/reference/pmod/pmodenc/
--
-- Changes:                 0.1, 2022-04-28, leuen4
--                              interface definition
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY inc IS
    PORT (
        clock, n_reset : IN STD_LOGIC;

        a   : IN STD_LOGIC;  -- signal of button A of the encoder shaft
        b   : IN STD_LOGIC;  -- signal of button B of the encoder shaft
        pos : OUT STD_LOGIC; -- pulse on positive CW rotation
        neg : OUT STD_LOGIC  -- pulse on negative CCW rotation
    );
END ENTITY inc;

ARCHITECTURE no_target_specific OF inc IS
BEGIN
END ARCHITECTURE no_target_specific;
