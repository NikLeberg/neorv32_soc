-- =============================================================================
-- File:                    wb_remap.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  wb_remap
--
-- Description:             Remap wishbone request from one address to the next.
--
-- Changes:                 0.1, 2023-09-25, leuen4
--                              initial version
--                          0.2, 2023-12-12, leuen4
--                              set generics to allow instantiation as toplevel
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_remap IS
    GENERIC (
        MEMORY_MAP_FROM : wb_map_t := (0 => (x"0000_0000", 1)); -- from what address
        MEMORY_MAP_TO   : wb_map_t := (0 => (x"f000_0000", 1))  -- to what address
    );
    PORT (
        -- Wishbone master interface --
        wb_master_i : IN wb_req_sig_t; -- original request
        wb_master_o : OUT wb_req_sig_t -- remapped request
    );
END ENTITY wb_remap;

ARCHITECTURE no_target_specific OF wb_remap IS
    CONSTANT address_ranges : natural_arr_t := wb_get_slave_address_ranges(MEMORY_MAP_FROM);
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
    coarse_decode : PROCESS (wb_master_i) IS
        CONSTANT msb_adr : NATURAL := WB_ADDRESS_WIDTH - 1; -- upper bound of address
        VARIABLE lsb_adr : NATURAL := 0; -- lower bound of address, depends on slave
    BEGIN
        -- As default: Assume that no remap of address takes place.
        wb_master_o <= wb_master_i;
        -- Loop over all map entries and compare its most significant bits to
        -- the current requested address.
        FOR i IN 0 TO MEMORY_MAP_FROM'length - 1 LOOP
            lsb_adr := address_ranges(i); -- lower bound of address
            IF wb_master_i.adr(msb_adr DOWNTO lsb_adr) = MEMORY_MAP_FROM(i).BASE_ADDRESS(msb_adr DOWNTO lsb_adr) THEN
                -- we have a match, remap the address
                wb_master_o.adr(msb_adr DOWNTO lsb_adr) <= MEMORY_MAP_TO(i).BASE_ADDRESS(msb_adr DOWNTO lsb_adr);
                EXIT;
            END IF;
        END LOOP;
    END PROCESS coarse_decode;

END ARCHITECTURE no_target_specific;
