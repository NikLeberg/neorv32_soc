-- =============================================================================
-- File:                    neorv32_wb_gateway.vhdl
--
-- Entity:                  neorv32_wb_gateway
--
-- Description:             Converter / Gateway from the neorv32 specific cpu
--                          internal data or instruction bus to the external
--                          Wishbone bus.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.4
--
-- Changes:                 0.1, 2023-04-17, NikLeberg
--                              initial version
--                          0.2, 2023-08-05, NikLeberg
--                              allow bus to be locked by lr/sc atomic ops
--                          0.3, 2023-09-30, NikLeberg
--                              reduce latency, immediately forward request
--                          0.4, 2024-01-01, NikLeberg
--                              update to new neorv32 stb and rw bus signals
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
        wb_master_o : OUT wb_req_sig_t; -- control and data from master to slave
        wb_master_i : IN wb_resp_sig_t  -- status and data from slave to master
    );
END ENTITY neorv32_wb_gateway;

ARCHITECTURE no_target_specific OF neorv32_wb_gateway IS

    -- Registers for bus access state.
    SIGNAL pending_request : STD_ULOGIC; -- a request is pending
    SIGNAL pending_atomic : STD_ULOGIC; -- lr/sc pair in progress
    SIGNAL active_request : STD_ULOGIC; -- a request is currently in progress

BEGIN

    -- CPU specific bus asserts stb_i for one clock only. Wishbone requires cyc
    -- & stb signals to be active for the whole transaction. Safe the pending
    -- state of an access and output that as cyc signal. 
    proc_request : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF rstn_i = '0' THEN
                pending_request <= '0';
                pending_atomic <= '0';
            ELSE
                -- Start a request on stb assertion. Request is pending until
                -- either ack or err was returned.
                IF req_i.stb = '1' THEN
                    pending_request <= '1';
                ELSIF (wb_master_i.ack OR wb_master_i.err) = '1' THEN
                    pending_request <= '0';
                END IF;
                -- Lock on to slave during atomic read/write access from lr/sc
                -- instruction pairs. Mark current req only as atomic if its a
                -- lr (rvso = 1, rw = 0). Otherwise a spurious single sc would
                -- lock the bus. Atomic request is reset on next stb assertion.
                IF pending_atomic = '0' AND (req_i.stb AND (NOT req_i.rw) AND req_i.rvso) = '1' THEN
                    pending_atomic <= '1';
                ELSIF pending_atomic = '1' AND req_i.stb = '1' THEN
                    pending_atomic <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS proc_request;

    -- A request is active if the current cycle has a strobe, or a previous
    -- request was not fullfulled yet.
    active_request <= req_i.stb OR pending_request;

    -- Map CPU bus to Wishbone.
    wb_master_o.cyc <= active_request OR pending_atomic; -- hold on to slave if atomic access
    wb_master_o.stb <= active_request;
    wb_master_o.we <= req_i.rw;
    wb_master_o.sel <= req_i.ben;
    wb_master_o.adr <= req_i.addr;
    wb_master_o.dat <= req_i.data;

    -- Map Wishbone to CPU bus.
    rsp_o.ack <= wb_master_i.ack;
    rsp_o.err <= wb_master_i.err;
    rsp_o.data <= wb_master_i.dat;

END ARCHITECTURE no_target_specific;
