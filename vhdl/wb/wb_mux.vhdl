-- =============================================================================
-- File:                    wb_mux.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.3
--
-- Entity:                  wb_mux
--
-- Description:             Wishbone interconnect for single master multi slave
--                          bus topology. One to many, implemented with muxes.
--
-- Changes:                 0.1, 2023-02-26, leuen4
--                              initial version
--                          0.2, 2023-03-19, leuen4
--                              simplify coarse decoding (unchanged behaviour)
--                          0.3, 2023-04-14, leuen4
--                              rename from wb_intercon to wb_mux
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_mux IS
    GENERIC (
        -- General --
        N_SLAVES   : NATURAL; -- number of connected slaves
        MEMORY_MAP : wb_map_t -- memory map of address space
    );
    PORT (
        -- Wishbone master interface --
        wb_master_i : IN wb_master_tx_sig_t;
        wb_master_o : OUT wb_master_rx_sig_t;
        -- Wishbone slave interface(s) --
        wb_slaves_o : OUT wb_slave_rx_arr_t(N_SLAVES - 1 DOWNTO 0);
        wb_slaves_i : IN wb_slave_tx_arr_t(N_SLAVES - 1 DOWNTO 0)
    );
END ENTITY wb_mux;

ARCHITECTURE no_target_specific OF wb_mux IS
    CONSTANT address_ranges : natural_arr_t := wb_get_slave_address_ranges(MEMORY_MAP);
    -- Number of the slave selected according to the address. Valid range
    -- 0 ... N_SLAVES - 1, a value of N_SLAVE indicates an invalid bus address
    -- and will auto terminate with error.
    SIGNAL slave_select : NATURAL RANGE N_SLAVES DOWNTO 0 := N_SLAVES;
    CONSTANT auto_terminate : wb_master_rx_sig_t := (ack => '0', err => '1', dat => (OTHERS => '0'));
BEGIN
    -- Check wishbone configuration.
    ASSERT WB_ADDRESS_WIDTH MOD 8 = 0
    REPORT "Wishbone config error: Width of address bus needs to be a multiple of 8."
        SEVERITY error;
    ASSERT WB_DATA_WIDTH MOD 8 = 0
    REPORT "Wishbone config error: Width of data bus needs to be a multiple of 8."
        SEVERITY error;
    ASSERT N_SLAVES = MEMORY_MAP'length
    REPORT "Wishbone config error: Number of slaves does not match with memory map definition."
        SEVERITY error;

    -- Coarse decode address of slaves.
    coarse_decode : PROCESS (wb_master_i) IS
        CONSTANT msb_adr : NATURAL := WB_ADDRESS_WIDTH - 1; -- upper bound of address
        VARIABLE lsb_adr : NATURAL := 0; -- lower bound of address, depends on slave
    BEGIN
        -- Default to an invalid index, this allows to auto terminate if no
        -- slave could be selected based on the address.
        slave_select <= N_SLAVES;
        -- Loop over all slaves and check the MSB of the address with their
        -- entry in the memory map.
        FOR i IN N_SLAVES - 1 DOWNTO 0 LOOP
            lsb_adr := address_ranges(i); -- lower bound of address
            IF wb_master_i.adr(msb_adr DOWNTO lsb_adr) = MEMORY_MAP(i).BASE_ADDRESS(msb_adr DOWNTO lsb_adr) THEN
                slave_select <= i;
            END IF;
        END LOOP;
    END PROCESS coarse_decode;

    -- Connect the master to the selected slave.
    slave_mux : PROCESS (wb_master_i, wb_slaves_i, slave_select) IS
    BEGIN
        -- Master -> Slave mux
        FOR i IN N_SLAVES - 1 DOWNTO 0 LOOP
            -- All shared master signals get assigned to each slave.
            wb_slaves_o(i) <= wb_master_i;
            -- The strobe signal gets only assigned to the selected slave.
            IF i /= slave_select THEN
                wb_slaves_o(i).stb <= '0';
            END IF;
        END LOOP;

        -- Slave -> Master mux
        IF slave_select /= N_SLAVES THEN
            wb_master_o <= wb_slaves_i(slave_select);
        ELSE
            -- Auto terminate with error when address is not covered in the
            -- memory map.
            wb_master_o <= auto_terminate;
        END IF;
    END PROCESS slave_mux;

END ARCHITECTURE no_target_specific;
