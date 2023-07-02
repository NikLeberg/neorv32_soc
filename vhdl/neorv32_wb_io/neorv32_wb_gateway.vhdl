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
        req_i : IN bus_req_t;  -- request bus
        rsp_o : OUT bus_rsp_t; -- response bus

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
                IF pending_request = '0' AND (req_i.re OR req_i.we) = '1' THEN
                    pending_request <= '1';
                    pending_write <= req_i.we;
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
    wb_master_o.sel <= req_i.ben;
    wb_master_o.adr <= req_i.addr;
    wb_master_o.dat <= req_i.data;

    -- Map Wishbone to CPU bus.
    rsp_o.ack <= wb_master_i.ack;
    rsp_o.err <= wb_master_i.err;
    rsp_o.data <= wb_master_i.dat;

END ARCHITECTURE no_target_specific;
