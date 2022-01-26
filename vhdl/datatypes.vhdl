-- =============================================================================
-- File:                    datatypes.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Package:                 datatypes
--
-- Description:             Definition of globaly available abstract data types.
--
-- Changes:                 0.1, 2021-12-15, leuen4
--                              initial version
--                          0.2, 2021-12-27, leuen4
--                              add NOTHING to operator_type to differentiate
--                              valid from invalid operators.
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE datatypes IS

    -- Keys A - F of keypad are mapped to following operators:
    TYPE operator_type IS (NOTHING, ADD, SUBTRACT, MULTIPLY, DIVIDE, ENTER, CHANGE_SIGN);

END PACKAGE datatypes;
