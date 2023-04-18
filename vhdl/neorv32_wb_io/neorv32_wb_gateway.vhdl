-- =============================================================================
-- File:                    neorv32_wb_gateway.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  neorv32_wb_gateway
--
-- Description:             Converter / Gateway from the neorv32 specific cpu
--                          internal data or instruction bus to the external
--                          Wishbone bus.
--
-- Changes:                 0.1, 2023-04-17, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

USE work.wb_pkg.ALL;

ENTITY neorv32_wb_gateway IS
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, async

        -- host access --
        addr_i : IN STD_ULOGIC_VECTOR(31 DOWNTO 0);  -- address
        rden_i : IN STD_ULOGIC;                      -- read enable
        wren_i : IN STD_ULOGIC;                      -- write enable
        ben_i  : IN STD_ULOGIC_VECTOR(03 DOWNTO 0);  -- byte write enable
        data_i : IN STD_ULOGIC_VECTOR(31 DOWNTO 0);  -- data in
        data_o : OUT STD_ULOGIC_VECTOR(31 DOWNTO 0); -- data out
        ack_o  : OUT STD_ULOGIC;                     -- transfer acknowledge
        err_o  : OUT STD_ULOGIC;                     -- transfer error

        -- Wishbone master interface --
        wb_master_o : OUT wb_master_tx_sig_t; -- control and data from master to slave
        wb_master_i : IN wb_master_rx_sig_t   -- status and data from slave to master
    );
END ENTITY neorv32_wb_gateway;

ARCHITECTURE no_target_specific OF neorv32_wb_gateway IS

    -- Register for pending bus access (rden_i or wren_i was asserted).
    SIGNAL pending_request : STD_ULOGIC;
    SIGNAL pending_write : STD_ULOGIC; -- set on write request

BEGIN

    -- CPU specific bus assert rden_i and wren_i for one clock only. Wishbone
    -- requires a cyc & stb signal to a active for the whole transaction. Safe
    -- the pending state of an access and output that as cyc signal. 
    proc_request : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF rstn_i = '0' THEN
                pending_request <= '0';
                pending_write <= '0';
            ELSE
                IF pending_request = '0' AND (rden_i OR wren_i) = '1' THEN
                    pending_request <= '1';
                    pending_write <= wren_i;
                ELSIF pending_request = '1' AND (wb_master_i.ack OR wb_master_i.err) = '1' THEN
                    pending_request <= '0';
                    pending_write <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS proc_request;

    -- Map CPU bus to Wishbone.
    wb_master_o.cyc <= pending_request;
    wb_master_o.stb <= pending_request;
    wb_master_o.we <= pending_write;
    wb_master_o.sel <= ben_i;
    wb_master_o.adr <= addr_i;
    wb_master_o.dat <= data_i;

    -- Map Wishbone to CPU bus.
    ack_o <= wb_master_i.ack;
    err_o <= wb_master_i.err;
    data_o <= wb_master_i.dat;

END ARCHITECTURE no_target_specific;
