-- =============================================================================
-- File:                    neorv32_wbp_gateway.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  neorv32_wbp_gateway
--
-- Description:             Converter / Gateway from the neorv32 specific cpu
--                          internal data or instruction bus to the external
--                          pipelined Wishbone bus.
--
-- Changes:                 0.1, 2024-08-23, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

USE work.wbp_pkg.ALL;

ENTITY neorv32_wbp_gateway IS
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, async

        -- host access --
        req_i : IN bus_req_t;  -- request bus
        rsp_o : OUT bus_rsp_t; -- response bus

        -- Wishbone master interface --
        wbp_mosi : OUT wbp_mosi_sig_t; -- control and data from master to slave
        wbp_miso : IN wbp_miso_sig_t   -- status and data from slave to master
    );
END ENTITY neorv32_wbp_gateway;

ARCHITECTURE no_target_specific OF neorv32_wbp_gateway IS

    TYPE transfer_state_t IS (IDLE, STALLED, PENDING, PAUSE);
    SIGNAL state, state_next : transfer_state_t := IDLE;

BEGIN

    -- CPU specific bus asserts stb for one clock only. Wishbone requires cyc to
    -- be active to the whole transaction, and stb to be asserted for as long as
    -- stall is not raised by slave. We also have to enforce an pause between
    -- back on back transactions, cyc must be low for at least one clk. 
    next_state_proc : PROCESS (state, req_i, wbp_miso) IS
    BEGIN
        state_next <= state; -- prevent latches
        CASE(state) IS
            WHEN IDLE =>
            IF req_i.stb = '1' THEN
                IF wbp_miso.stall = '1' THEN
                    state_next <= STALLED;
                ELSE
                    state_next <= PENDING;
                END IF;
            END IF;

            WHEN STALLED =>
            IF wbp_miso.stall = '0' THEN
                state_next <= PENDING;
            END IF;

            WHEN PENDING =>
            IF (wbp_miso.ack OR wbp_miso.err) = '1' THEN
                state_next <= PAUSE;
            END IF;

            WHEN PAUSE =>
            IF req_i.stb = '1' THEN
                state_next <= STALLED;
            ELSE
                state_next <= IDLE;
            END IF;

            WHEN OTHERS =>
            state_next <= IDLE;
        END CASE;
    END PROCESS next_state_proc;

    state_memory_proc : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF rstn_i = '0' THEN
                state <= IDLE;
            ELSE
                state <= state_next;
            END IF;
        END IF;
    END PROCESS state_memory_proc;

    -- Map CPU bus to Wishbone.
    wbp_mosi.cyc <= req_i.stb WHEN state = IDLE ELSE
    '1' WHEN state = STALLED OR state = PENDING ELSE
    '0';
    wbp_mosi.stb <= req_i.stb WHEN state = IDLE ELSE
    '1' WHEN state = STALLED ELSE
    '0';
    wbp_mosi.we <= req_i.rw;
    wbp_mosi.sel <= req_i.ben;
    wbp_mosi.adr <= req_i.addr;
    wbp_mosi.dat <= req_i.data;

    -- Map Wishbone to CPU bus.
    rsp_o.ack <= wbp_miso.ack;
    rsp_o.err <= wbp_miso.err;
    rsp_o.data <= wbp_miso.dat;

END ARCHITECTURE no_target_specific;
