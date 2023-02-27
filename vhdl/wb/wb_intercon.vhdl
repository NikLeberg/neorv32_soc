-- =============================================================================
-- File:                    wb_intercon.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  wb_intercon
--
-- Description:             Wishbone interconnect for single master multi slave
--                          bus topology. One to many, implemented with muxes.
--
-- Changes:                 0.1, 2023-02-26, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_intercon IS
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
END ENTITY wb_intercon;

ARCHITECTURE no_target_specific OF wb_intercon IS
    CONSTANT coarse_decode_msb_bit_nums : natural_arr_t := wb_calc_coarse_decode_msb_bit_nums(MEMORY_MAP);
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
    REPORT "Wishbone config error: Number of slaves does not match with memoery map definition."
        SEVERITY error;

    -- Coarse decode address of slaves.
    coarse_decode : PROCESS (wb_master_i) IS
    BEGIN
        -- Default to an invalid index, this allows to auto terminate if no
        -- slave could be selected based on the address.
        slave_select <= N_SLAVES;
        -- Loop over all slaves and check the MSB of the address with their
        -- entry in the memory map.
        FOR i IN N_SLAVES - 1 DOWNTO 0 LOOP
            IF wb_master_i.adr(WB_ADDRESS_WIDTH - 1 DOWNTO coarse_decode_msb_bit_nums(i)) = MEMORY_MAP(i).BASE_ADDRESS(WB_ADDRESS_WIDTH - 1 DOWNTO coarse_decode_msb_bit_nums(i)) THEN
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
