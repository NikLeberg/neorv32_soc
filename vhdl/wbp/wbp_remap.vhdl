-- =============================================================================
-- File:                    wbp_remap.vhdl
--
-- Entity:                  wbp_remap
--
-- Description:             Remap wishbone request from one address to the next.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.1
--
-- Changes:                 0.1, 2024-08-25, NikLeberg
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.wbp_pkg.ALL;

ENTITY wbp_remap IS
    GENERIC (
        MEMORY_MAP_FROM : wbp_map_t := (0 => (x"0000_0000", 1)); -- from what address
        MEMORY_MAP_TO   : wbp_map_t := (0 => (x"f000_0000", 1))  -- to what address
    );
    PORT (
        -- Wishbone master interface --
        wbp_orig_mosi  : IN wbp_mosi_sig_t; -- original request
        wbp_remap_mosi : OUT wbp_mosi_sig_t -- remapped request
    );
END ENTITY wbp_remap;

ARCHITECTURE no_target_specific OF wbp_remap IS
BEGIN
    -- Check memory map configuration.
    ASSERT MEMORY_MAP_FROM'length = MEMORY_MAP_TO'length
    REPORT "Wishbone config error: Each from/to memory map must contain the same amount of entries."
        SEVERITY error;
    check_size_gen : FOR i IN 0 TO MEMORY_MAP_FROM'length - 1 GENERATE
        ASSERT MEMORY_MAP_FROM(i).SIZE = MEMORY_MAP_TO(i).SIZE
        REPORT "Wishbone config error: Size of the 'from' memory map entry must be identical to the 'to' memory map."
            SEVERITY error;
    END GENERATE check_size_gen;

    -- Decode addresses and remap on match.
    coarse_decode : PROCESS (wbp_orig_mosi) IS
        CONSTANT msb : NATURAL := WBP_ADDRESS_WIDTH - 1; -- upper bound of address
        VARIABLE lsb : NATURAL := 0; -- lower bound of address, depends on slave
    BEGIN
        -- As default: Assume that no remapping of address takes place.
        wbp_remap_mosi <= wbp_orig_mosi;
        -- Loop over all map entries and compare its most significant bits to
        -- the current requested address.
        FOR i IN 0 TO MEMORY_MAP_FROM'length - 1 LOOP
            lsb := wbp_get_slave_address_range(MEMORY_MAP_FROM(i)); -- lower bound
            IF wbp_orig_mosi.adr(msb DOWNTO lsb) = MEMORY_MAP_FROM(i).BASE_ADDRESS(msb DOWNTO lsb) THEN
                -- we have a match, remap the address
                wbp_remap_mosi.adr(msb DOWNTO lsb) <= MEMORY_MAP_TO(i).BASE_ADDRESS(msb DOWNTO lsb);
                EXIT;
            END IF;
        END LOOP;
    END PROCESS coarse_decode;

END ARCHITECTURE no_target_specific;
