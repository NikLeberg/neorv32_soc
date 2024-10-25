-- =============================================================================
-- File:                    wbp_mux.vhdl
--
-- Entity:                  wbp_mux
--
-- Description:             Wishbone pipelined interconnect for single master
--                          multi slave bus topology. One to many.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.1
--
-- Changes:                 0.1, 2024-08-23, NikLeberg
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.wbp_pkg.ALL;

ENTITY wbp_mux IS
    GENERIC (
        -- General --
        N_SLAVES   : NATURAL;  -- number of connected slaves
        MEMORY_MAP : wbp_map_t -- memory map of address space
    );
    PORT (
        -- Wishbone master interface --
        wbp_master_mosi : IN wbp_mosi_sig_t;
        wbp_master_miso : OUT wbp_miso_sig_t;
        -- Wishbone slave interface(s) --
        wbp_slaves_mosi : OUT wbp_mosi_arr_t(N_SLAVES - 1 DOWNTO 0);
        wbp_slaves_miso : IN wbp_miso_arr_t(N_SLAVES - 1 DOWNTO 0)
    );
END ENTITY wbp_mux;

ARCHITECTURE no_target_specific OF wbp_mux IS
    -- Number of the slave selected according to the address. Valid range
    -- 0 ... N_SLAVES - 1, a value of N_SLAVE indicates an invalid bus address
    -- and will auto terminate with error.
    SIGNAL slave_select : NATURAL RANGE N_SLAVES DOWNTO 0 := N_SLAVES;
    CONSTANT auto_terminate : wbp_miso_sig_t := (stall => '0', ack => '0', err => '1', dat => (OTHERS => '0'));
BEGIN
    -- Check wishbone configuration.
    ASSERT N_SLAVES = MEMORY_MAP'length
    REPORT "Wishbone config error: Number of slaves does not match with memory map definition."
        SEVERITY error;

    -- Coarse decode address of slaves.
    coarse_decode : PROCESS (wbp_master_mosi) IS
        CONSTANT msb : NATURAL := WBP_ADDRESS_WIDTH - 1; -- upper bound of address
        VARIABLE lsb : NATURAL := 0; -- lower bound of address, depends on slave
    BEGIN
        -- Default to an invalid index, this allows to auto terminate if no
        -- slave could be selected based on the address.
        slave_select <= N_SLAVES;
        -- Loop over all slaves and check the MSB of the address with their
        -- entry in the memory map.
        FOR s IN N_SLAVES - 1 DOWNTO 0 LOOP
            lsb := wbp_get_slave_address_range(MEMORY_MAP(s)); -- lower bound
            IF wbp_master_mosi.adr(msb DOWNTO lsb) = MEMORY_MAP(s).BASE_ADDRESS(msb DOWNTO lsb) THEN
                slave_select <= s;
            END IF;
        END LOOP;
    END PROCESS coarse_decode;

    -- Connect the master to the selected slave.
    slave_mux : PROCESS (wbp_master_mosi, wbp_slaves_miso, slave_select) IS
    BEGIN
        -- Master -> Slave mux
        FOR i IN N_SLAVES - 1 DOWNTO 0 LOOP
            -- All shared master signals get assigned to each slave.
            wbp_slaves_mosi(i) <= wbp_master_mosi;
            -- The cyc and stb signal get only assigned to the selected slave.
            IF i /= slave_select THEN
                wbp_slaves_mosi(i).cyc <= '0';
                wbp_slaves_mosi(i).stb <= '0';
            END IF;
        END LOOP;

        -- Slave -> Master mux
        IF slave_select /= N_SLAVES THEN
            wbp_master_miso <= wbp_slaves_miso(slave_select);
        ELSE
            -- Auto terminate with error when address is not covered in the
            -- memory map.
            wbp_master_miso <= auto_terminate;
        END IF;
    END PROCESS slave_mux;

END ARCHITECTURE no_target_specific;
