-- =============================================================================
-- File:                    neorv32_wbp_gateway.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.4
--
-- Entity:                  neorv32_wbp_gateway
--
-- Description:             Converter / Gateway from the neorv32 specific cpu
--                          internal data or instruction bus to the external
--                          pipelined Wishbone bus.
--
-- Note:                    To allow atomic lr/sc operations to eventually
--                          succeed, no instruction bus access must interfere
--                          inbetween. To guarantee this, an i-cache of at least
--                          32 words must be implemented (2 * 16 where 16 is the
--                          RISC-V ISA specification of a bounded lr/sc seq).
--
-- Changes:                 0.1, 2024-08-23, leuen4
--                              initial version
--                          0.2, 2024-09-09, leuen4
--                              add support for atomic lr/sc sequences
--                          0.3, 2024-10-05, leuen4
--                              delay BTB transactions also for error responses
--                              fix order of `rvsc.pending` reset
--                              fix reset of `rvsc.expect_sc`
--                          0.4, 2024-10-23, leuen4
--                              improve throughput for accesses to same slave
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

    -- address comparator
    TYPE comp_t IS RECORD
        addr : STD_ULOGIC_VECTOR(31 DOWNTO 2);
        addr_next : STD_ULOGIC_VECTOR(31 DOWNTO 2);
        is_same_slave : STD_ULOGIC; -- same slave assuming 4k boundaries
        is_same_addr : STD_ULOGIC;
    END RECORD comp_t;
    SIGNAL comp : comp_t;

    -- back-to-back prevention
    TYPE btb_state_t IS (IDLE, ACK, DELAY);
    TYPE btb_t IS RECORD
        state : btb_state_t;
        state_next : btb_state_t;
        stb : STD_ULOGIC; -- processed strobe
    END RECORD btb_t;
    SIGNAL btb : btb_t;

    -- reservation station and transaction cycle controller
    TYPE rvsc_t IS RECORD
        is_lr : STD_ULOGIC; -- marks an lr operation (rvso = 1; rw = 0)
        is_sc : STD_ULOGIC; -- marks an sc operation (rvso = 1; rw = 1)
        is_break : STD_ULOGIC; -- marks that no sc did follow the lr
        is_failure : STD_ULOGIC; -- marks that current sc is not valid
        expect_sc : STD_ULOGIC;
        expect_sc_next : STD_ULOGIC;
        pending : STD_ULOGIC;
        pending_next : STD_ULOGIC;
        int_stb : STD_ULOGIC; -- if inbetween stb needs to be repeated
        int_stb_next : STD_ULOGIC;
        int_ack : STD_ULOGIC; -- local ack for failed sc operations
        int_ack_next : STD_ULOGIC;
        cyc : STD_ULOGIC; -- generated cycle
        stb : STD_ULOGIC; -- processed strobe
    END RECORD rvsc_t;
    SIGNAL rvsc : rvsc_t;

    -- stall handling
    TYPE stall_t IS RECORD
        repeat : STD_ULOGIC;
        repeat_next : STD_ULOGIC;
        stb : STD_ULOGIC; -- processed strobe
    END RECORD stall_t;
    SIGNAL stall : stall_t;

BEGIN

    -- Track last accessed address for back-to-back and reservation set
    -- controllers. Complete match is required for reservation, partial match at
    -- 4k boundary is required for BTB.
    comp.addr_next <= req_i.addr(31 DOWNTO 2) WHEN req_i.stb = '1' ELSE
    comp.addr;
    comp.is_same_slave <= '1' WHEN comp.addr(31 DOWNTO 12) = req_i.addr(31 DOWNTO 12) ELSE
    '0';
    comp.is_same_addr <= comp.is_same_slave WHEN comp.addr(11 DOWNTO 2) = req_i.addr(11 DOWNTO 2) ELSE
    '0';

    -- Internal CPU transactions can be done back-to-back i.e. after an ack, the
    -- next stb can immediately follow on the next clock. This is not allowed in
    -- wishbone unless it addresses the same slave. Otherwise if back-to-back
    -- transactions are detected, stb must be delayed.
    btb.state_next <= ACK WHEN btb.state = IDLE AND (wbp_miso.ack OR wbp_miso.err) = '1' ELSE
    DELAY WHEN btb.state = ACK AND req_i.stb = '1' AND comp.is_same_slave = '0' ELSE
    IDLE WHEN btb.state = ACK AND (req_i.stb = '0' OR comp.is_same_slave = '1') ELSE
    IDLE WHEN btb.state = DELAY ELSE
    btb.state;

    btb.stb <= req_i.stb WHEN btb.state = IDLE ELSE
    req_i.stb WHEN btb.state = ACK AND comp.is_same_slave = '1' ELSE
    '1' WHEN btb.state = DELAY ELSE
    '0';

    -- Incoming transactions from CPU are of either the d-bus or the i-bus.
    -- Transactions of the d-bus may be of atomic type (rsvo = '1') and mark
    -- corresponding lr or sc operations. While these are ongoing, we want to
    -- keep the cyc signal asserted to not loose arbitration of accessed slave
    -- and guarantee the atomic access. The lr/sc sequence may be intertwined
    -- with i-bus accesses or erroneous d-bus accesses. These must be let
    -- through as otherwise CPU gets stalled indefinitely. As these happened we
    -- can no longer guarantee atomicity and the sequence will be failed.
    -- Eventually, the i-cache (which is required) will contain the full
    -- sequence and will no longer interrupt lr/sc.
    rvsc.is_lr <= req_i.rvso AND (NOT req_i.rw);
    rvsc.is_sc <= req_i.rvso AND req_i.rw;

    -- not the expected sc after an lr
    rvsc.is_break <= btb.stb AND (NOT req_i.rvso) AND rvsc.expect_sc;

    -- invalid sc operation, either address missmatch or interrupted since lr
    rvsc.is_failure <= btb.stb AND rvsc.is_sc AND (comp.is_same_addr NAND rvsc.expect_sc);

    rvsc.expect_sc_next <= '1' WHEN (rvsc.is_lr AND btb.stb) = '1' ELSE
    '0' WHEN (btb.stb OR wbp_miso.err) = '1' ELSE
    rvsc.expect_sc;

    -- transaction pending starting from stb until ack or err
    rvsc.pending_next <= '0' WHEN (wbp_miso.ack OR wbp_miso.err) = '1' ELSE
    '1' WHEN (btb.stb AND (NOT rvsc.is_failure)) = '1' ELSE
    rvsc.pending;

    rvsc.int_stb_next <= rvsc.is_break;
    rvsc.int_ack_next <= rvsc.is_failure;

    -- block strobe if it is either:
    --  - not the expected sc after an lr, or
    --  - a failing sc operation
    rvsc.cyc <= ((btb.stb OR rvsc.expect_sc) AND (rvsc.is_break NOR rvsc.is_failure)) OR rvsc.pending;
    rvsc.stb <= (btb.stb AND (rvsc.is_break NOR rvsc.is_failure)) OR rvsc.int_stb;

    -- In pipelined wishbone, slaves may stall transactions. As no parallel
    -- transactions will ever be issued by neorv32 cpu, we don't need to
    -- buffer any values. We only need to repeat the strobe for as long as the
    -- slave is stalling.
    stall.repeat_next <= '1' WHEN rvsc.stb = '1' AND wbp_miso.stall = '1' ELSE
    '0' WHEN wbp_miso.stall = '0' ELSE
    stall.repeat;

    stall.stb <= rvsc.cyc AND (rvsc.stb OR stall.repeat);

    state_memory_proc : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF rstn_i = '0' THEN
                comp.addr <= (OTHERS => '0');
                btb.state <= IDLE;
                rvsc.expect_sc <= '0';
                rvsc.pending <= '0';
                rvsc.int_stb <= '0';
                rvsc.int_ack <= '0';
                stall.repeat <= '0';
            ELSE
                comp.addr <= comp.addr_next;
                btb.state <= btb.state_next;
                rvsc.expect_sc <= rvsc.expect_sc_next;
                rvsc.pending <= rvsc.pending_next;
                rvsc.int_stb <= rvsc.int_stb_next;
                rvsc.int_ack <= rvsc.int_ack_next;
                stall.repeat <= stall.repeat_next;
            END IF;
        END IF;
    END PROCESS state_memory_proc;

    -- Map CPU bus to Wishbone.
    wbp_mosi.cyc <= rvsc.cyc;
    wbp_mosi.stb <= stall.stb;
    wbp_mosi.we <= req_i.rw;
    wbp_mosi.sel <= req_i.ben;
    wbp_mosi.adr <= req_i.addr;
    wbp_mosi.dat <= req_i.data;

    -- Map Wishbone to CPU bus.
    rsp_o.err <= wbp_miso.err;
    rsp_o.data(31 DOWNTO 1) <= wbp_miso.dat(31 DOWNTO 1);
    -- insert error value (= 1) for CPU on failed sc and ack locally
    rsp_o.ack <= wbp_miso.ack OR rvsc.int_ack;
    rsp_o.data(0) <= wbp_miso.dat(0) OR rvsc.int_ack;

END ARCHITECTURE no_target_specific;
