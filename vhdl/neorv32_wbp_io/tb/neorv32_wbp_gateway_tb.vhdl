-- =============================================================================
-- File:                    neorv32_wbp_gateway_tb.vhdl
--
-- Entity:                  neorv32_wbp_gateway_tb
--
-- Description:             Testbench for the NEORV32 CPU bus to pipelined
--                          Wishbone gateway.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.1
--
-- Changes:                 0.1, 2024-10-23, NikLeberg
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

USE work.wbp_pkg.ALL;

ENTITY neorv32_wbp_gateway_tb IS
    -- Testbench needs no ports.
END ENTITY neorv32_wbp_gateway_tb;

ARCHITECTURE simulation OF neorv32_wbp_gateway_tb IS

    -- Signals for sequential DUTs.
    CONSTANT CLK_PERIOD : DELAY_LENGTH := 20 ns; -- 50 MHz
    SIGNAL clk : STD_LOGIC := '1';
    SIGNAL rstn : STD_LOGIC := '0';
    SIGNAL tb_done : STD_LOGIC := '0'; -- flag end of tests

    -- Signals for connecting to the DUT.
    SIGNAL req : bus_req_t := (
        addr => (OTHERS => '0'), data => (OTHERS => '0'), ben => (OTHERS => '0'),
        stb => '0', rw => '0', src => '0', priv => '0', rvso => '0', fence => '0'
    );
    SIGNAL rsp : bus_rsp_t;
    SIGNAL wbp_mosi : wbp_mosi_sig_t;
    SIGNAL wbp_miso : wbp_miso_sig_t := (
        stall => '0', ack => '0', err => '0', dat => (OTHERS => '0')
    );

    -- Helper signals for checking transactions.
    SIGNAL wbp_pending : INTEGER := 0;
    SIGNAL cpu_pending : INTEGER := 0;

BEGIN
    -- Instantiate the device under test.
    dut : ENTITY work.neorv32_wbp_gateway
        PORT MAP(
            -- Global control --
            clk_i  => clk,
            rstn_i => rstn,
            -- host access --
            req_i => req,
            rsp_o => rsp,
            -- Wishbone master interface --
            wbp_mosi => wbp_mosi,
            wbp_miso => wbp_miso
        );

    -- Clock that stops after all tests are done.
    clk <= '0' WHEN tb_done = '1' ELSE
        NOT clk AFTER 0.5 * CLK_PERIOD;

    -- Power on reset the DUT, lasts two clock cycles.
    rstn <= '0', '1' AFTER 2 * CLK_PERIOD;

    test : PROCESS IS
        PROCEDURE cpu_clear IS
        BEGIN
            req <= (
                addr => (OTHERS => '0'), data => (OTHERS => '0'), ben => (OTHERS => '0'),
                stb => '0', rw => '0', src => '0', priv => '0', rvso => '0', fence => '0'
                );
        END PROCEDURE;

        PROCEDURE cpu_clear_stb IS
        BEGIN
            req.stb <= '0';
        END PROCEDURE;

        PROCEDURE cpu_read (addr : STD_ULOGIC_VECTOR) IS
        BEGIN
            req <= (
                addr => addr, data => (OTHERS => 'X'), ben => x"F", stb => '1',
                rw => '0', src => '0', priv => '0', rvso => '0', fence => '0'
                );
        END PROCEDURE;

        PROCEDURE cpu_write (addr, data : STD_ULOGIC_VECTOR) IS
        BEGIN
            req <= (
                addr => addr, data => data, ben => x"F", stb => '1',
                rw => '1', src => '0', priv => '0', rvso => '0', fence => '0'
                );
        END PROCEDURE;

        PROCEDURE cpu_lr (addr : STD_ULOGIC_VECTOR) IS
        BEGIN
            req <= (
                addr => addr, data => (OTHERS => 'X'), ben => x"F", stb => '1',
                rw => '0', src => '0', priv => '0', rvso => '1', fence => '0'
                );
        END PROCEDURE;

        PROCEDURE cpu_sc (addr, data : STD_ULOGIC_VECTOR) IS
        BEGIN
            req <= (
                addr => addr, data => data, ben => x"F", stb => '1',
                rw => '1', src => '0', priv => '0', rvso => '1', fence => '0'
                );
        END PROCEDURE;

        PROCEDURE assert_equal (a, b : STD_ULOGIC_VECTOR) IS
        BEGIN
            ASSERT a = b
            REPORT to_hstring(a) & " is not equal to " & to_hstring(b)
                SEVERITY failure;
        END PROCEDURE;

        PROCEDURE assert_high (a : STD_LOGIC) IS
        BEGIN
            ASSERT a = '1'
            REPORT "expected '1'"
                SEVERITY failure;
        END PROCEDURE;

        PROCEDURE assert_low (a : STD_LOGIC) IS
        BEGIN
            ASSERT a = '0'
            REPORT "expected '0'"
                SEVERITY failure;
        END PROCEDURE;

        PROCEDURE cpu_assert_read (data : STD_ULOGIC_VECTOR) IS
        BEGIN
            assert_high(rsp.ack);
            assert_low(rsp.err);
            assert_equal(data, rsp.data);
        END PROCEDURE;

        PROCEDURE cpu_assert_write IS
        BEGIN
            assert_high(rsp.ack);
            assert_low(rsp.err);
        END PROCEDURE;

        PROCEDURE cpu_assert_err IS
        BEGIN
            assert_low(rsp.ack);
            assert_high(rsp.err);
        END PROCEDURE;

        PROCEDURE cpu_assert_idle IS
        BEGIN
            assert_low(rsp.ack);
            assert_low(rsp.err);
        END PROCEDURE;

        PROCEDURE cpu_assert_sc_success IS
        BEGIN
            assert_high(rsp.ack);
            assert_low(rsp.err);
            assert_equal(x"00000000", rsp.data);
        END PROCEDURE;

        PROCEDURE cpu_assert_sc_failure IS
        BEGIN
            assert_high(rsp.ack);
            assert_low(rsp.err);
            assert_equal(x"00000001", rsp.data);
        END PROCEDURE;

        PROCEDURE wbp_assert_read (addr : STD_ULOGIC_VECTOR) IS
        BEGIN
            assert_equal(addr, wbp_mosi.adr);
            assert_low(wbp_mosi.we);
            assert_equal(x"F", wbp_mosi.sel);
            assert_high(wbp_mosi.cyc);
            assert_high(wbp_mosi.stb);
        END PROCEDURE;

        PROCEDURE wbp_assert_read_pending (addr : STD_ULOGIC_VECTOR) IS
        BEGIN
            assert_equal(addr, wbp_mosi.adr);
            assert_low(wbp_mosi.we);
            assert_equal(x"F", wbp_mosi.sel);
            assert_high(wbp_mosi.cyc);
            assert_low(wbp_mosi.stb);
        END PROCEDURE;

        PROCEDURE wbp_assert_write (addr, data : STD_ULOGIC_VECTOR) IS
        BEGIN
            assert_equal(addr, wbp_mosi.adr);
            assert_equal(data, wbp_mosi.dat);
            assert_high(wbp_mosi.we);
            assert_equal(x"F", wbp_mosi.sel);
            assert_high(wbp_mosi.cyc);
            assert_high(wbp_mosi.stb);
        END PROCEDURE;

        PROCEDURE wbp_assert_write_pending (addr, data : STD_ULOGIC_VECTOR) IS
        BEGIN
            assert_equal(addr, wbp_mosi.adr);
            assert_equal(data, wbp_mosi.dat);
            assert_high(wbp_mosi.we);
            assert_equal(x"F", wbp_mosi.sel);
            assert_high(wbp_mosi.cyc);
            assert_low(wbp_mosi.stb);
        END PROCEDURE;

        PROCEDURE wbp_assert_idle IS
        BEGIN
            assert_low(wbp_mosi.cyc);
            assert_low(wbp_mosi.stb);
        END PROCEDURE;

        PROCEDURE wbp_clear IS
        BEGIN
            wbp_miso <= (stall => '0', ack => '0', err => '0', dat => (OTHERS => '0'));
        END PROCEDURE;

        PROCEDURE wbp_stall IS
        BEGIN
            wbp_miso <= (stall => '1', ack => '0', err => '0', dat => (OTHERS => '0'));
        END PROCEDURE;

        PROCEDURE wbp_ack_write IS
        BEGIN
            wbp_miso <= (stall => '0', ack => '1', err => '0', dat => (OTHERS => '0'));
        END PROCEDURE;

        PROCEDURE wbp_ack_read(data : STD_ULOGIC_VECTOR) IS
        BEGIN
            wbp_miso <= (stall => '0', ack => '1', err => '0', dat => data);
        END PROCEDURE;

        PROCEDURE wbp_err IS
        BEGIN
            wbp_miso <= (stall => '0', ack => '0', err => '1', dat => (OTHERS => '0'));
        END PROCEDURE;

        PROCEDURE teardown IS
        BEGIN
            WAIT UNTIL rising_edge(clk);
            cpu_clear;
            wbp_clear;
            WAIT FOR 1 ns;
            cpu_assert_idle;
            wbp_assert_idle;
            WAIT UNTIL rising_edge(clk);
            cpu_assert_idle;
            wbp_assert_idle;
        END PROCEDURE;
    BEGIN
        -- Wait for power on reset to finish.
        cpu_clear;
        wbp_clear;
        WAIT UNTIL rising_edge(rstn);
        WAIT UNTIL rising_edge(clk);

        -- CPU read request translated to Wishbone.
        cpu_read(x"dead_beef");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"dead_beef");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_read(x"5555_5555");
        WAIT FOR 1 ns;
        cpu_assert_read(x"5555_5555");
        wbp_assert_read_pending(x"dead_beef");
        teardown;

        -- CPU write request translated to Wishbone.
        cpu_write(x"fefe_fefe", x"1234_5678");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"fefe_fefe", x"1234_5678");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_write;
        WAIT FOR 1 ns;
        cpu_assert_write;
        wbp_assert_write_pending(x"fefe_fefe", x"1234_5678");
        teardown;

        -- Stalled read request.
        wbp_stall;
        cpu_read(x"0000_1111");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"0000_1111");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"0000_1111");
        WAIT UNTIL rising_edge(clk);
        wbp_clear;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"0000_1111");
        WAIT UNTIL rising_edge(clk);
        wbp_ack_read(x"1111_0000");
        WAIT FOR 1 ns;
        cpu_assert_read(x"1111_0000");
        wbp_assert_read_pending(x"0000_1111");
        teardown;

        -- Stalled write request.
        wbp_stall;
        cpu_write(x"0000_2222", x"abab_abab");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"0000_2222", x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"0000_2222", x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        wbp_clear;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"0000_2222", x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        wbp_ack_write;
        WAIT FOR 1 ns;
        cpu_assert_write;
        wbp_assert_write_pending(x"0000_2222", x"abab_abab");
        teardown;

        -- Delayed read request.
        cpu_read(x"dead_beef");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"dead_beef");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read_pending(x"dead_beef");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_read_pending(x"dead_beef");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_read_pending(x"dead_beef");
        WAIT UNTIL rising_edge(clk);
        wbp_ack_read(x"5555_5555");
        WAIT FOR 1 ns;
        cpu_assert_read(x"5555_5555");
        wbp_assert_read_pending(x"dead_beef");
        teardown;

        -- Delayed write request.
        cpu_write(x"0505_0505", x"8888_8888");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"0505_0505", x"8888_8888");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write_pending(x"0505_0505", x"8888_8888");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_write_pending(x"0505_0505", x"8888_8888");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_write_pending(x"0505_0505", x"8888_8888");
        WAIT UNTIL rising_edge(clk);
        wbp_ack_write;
        WAIT FOR 1 ns;
        cpu_assert_write;
        wbp_assert_write_pending(x"0505_0505", x"8888_8888");
        teardown;

        -- Stalled and delayed read request.
        wbp_stall;
        cpu_read(x"abab_abab");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_read(x"abab_abab");
        wbp_clear;
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_read(x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_read_pending(x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        wbp_ack_read(x"9999_9999");
        WAIT FOR 1 ns;
        cpu_assert_read(x"9999_9999");
        wbp_assert_read_pending(x"abab_abab");
        teardown;

        -- Stalled and delayed write request.
        wbp_stall;
        cpu_write(x"0000_2222", x"abab_abab");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"0000_2222", x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"0000_2222", x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_write(x"0000_2222", x"abab_abab");
        wbp_clear;
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_write(x"0000_2222", x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_write_pending(x"0000_2222", x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        wbp_ack_write;
        WAIT FOR 1 ns;
        cpu_assert_write;
        wbp_assert_write_pending(x"0000_2222", x"abab_abab");
        teardown;

        -- Error on read request.
        cpu_read(x"dead_beef");
        WAIT FOR 1 ns;
        wbp_assert_read(x"dead_beef");
        cpu_assert_idle;
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_err;
        WAIT FOR 1 ns;
        cpu_assert_err;
        wbp_assert_read_pending(x"dead_beef");
        teardown;

        -- Error on write request.
        cpu_write(x"2222_2222", x"dead_beef");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"2222_2222", x"dead_beef");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_err;
        WAIT FOR 1 ns;
        cpu_assert_err;
        teardown;

        -- Delayed error on read request.
        cpu_read(x"abcd_def0");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"abcd_def0");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read_pending(x"abcd_def0");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_read_pending(x"abcd_def0");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_read_pending(x"abcd_def0");
        WAIT UNTIL rising_edge(clk);
        wbp_err;
        WAIT FOR 1 ns;
        cpu_assert_err;
        wbp_assert_read_pending(x"abcd_def0");
        teardown;

        -- Delayed error on write request.
        cpu_write(x"fefe_fefe", x"f2f2_f2f2");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"fefe_fefe", x"f2f2_f2f2");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write_pending(x"fefe_fefe", x"f2f2_f2f2");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_write_pending(x"fefe_fefe", x"f2f2_f2f2");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_write_pending(x"fefe_fefe", x"f2f2_f2f2");
        WAIT UNTIL rising_edge(clk);
        wbp_err;
        WAIT FOR 1 ns;
        cpu_assert_err;
        wbp_assert_write_pending(x"fefe_fefe", x"f2f2_f2f2");
        teardown;

        -- Stalled and delayed error in read request.
        wbp_stall;
        cpu_read(x"abab_abab");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_read(x"abab_abab");
        wbp_clear;
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_read(x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_read_pending(x"abab_abab");
        WAIT UNTIL rising_edge(clk);
        wbp_err;
        WAIT FOR 1 ns;
        cpu_assert_err;
        wbp_assert_read_pending(x"abab_abab");
        teardown;

        -- Stalled and delayed error in write request.
        wbp_stall;
        cpu_write(x"bada_feee", x"ffff_ffff");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"bada_feee", x"ffff_ffff");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"bada_feee", x"ffff_ffff");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_write(x"bada_feee", x"ffff_ffff");
        wbp_clear;
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_write(x"bada_feee", x"ffff_ffff");
        WAIT UNTIL rising_edge(clk);
        cpu_assert_idle;
        wbp_assert_write_pending(x"bada_feee", x"ffff_ffff");
        WAIT UNTIL rising_edge(clk);
        wbp_err;
        WAIT FOR 1 ns;
        cpu_assert_err;
        wbp_assert_write_pending(x"bada_feee", x"ffff_ffff");
        teardown;

        -- Back-to-back read request to same slave.
        cpu_read(x"dead_beef");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"dead_beef");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_read(x"5555_5555");
        WAIT FOR 1 ns;
        cpu_assert_read(x"5555_5555");
        wbp_assert_read_pending(x"dead_beef");
        WAIT UNTIL rising_edge(clk);
        wbp_clear;
        cpu_read(x"dead_bead"); -- start of second read, same slave
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"dead_bead");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_read(x"bead_bead");
        WAIT FOR 1 ns;
        cpu_assert_read(x"bead_bead");
        wbp_assert_read_pending(x"dead_bead");
        teardown;

        -- Back-to-back write request to same slave.
        cpu_write(x"fefe_fefe", x"0000_0001");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"fefe_fefe", x"0000_0001");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_write;
        WAIT FOR 1 ns;
        cpu_assert_write;
        wbp_assert_write_pending(x"fefe_fefe", x"0000_0001");
        WAIT UNTIL rising_edge(clk);
        wbp_clear;
        cpu_write(x"fefe_fbbb", x"0000_0002"); -- start of second write, same slave
        WAIT FOR 1 ns;
        cpu_assert_idle;
        -- wbp_assert_write(x"fefe_fbbb", x"0000_0002");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_write;
        WAIT FOR 1 ns;
        cpu_assert_write;
        -- wbp_assert_write_pending(x"fefe_fbbb", x"0000_0002");
        teardown;

        -- Back-to-back read request to different slave.
        cpu_read(x"dead_beef");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"dead_beef");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_read(x"5555_5555");
        WAIT FOR 1 ns;
        cpu_assert_read(x"5555_5555");
        wbp_assert_read_pending(x"dead_beef");
        WAIT UNTIL rising_edge(clk);
        wbp_clear;
        cpu_read(x"feed_feed"); -- start of second read, different slave
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_idle;
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"feed_feed");
        WAIT UNTIL rising_edge(clk);
        wbp_ack_read(x"feed_feed");
        WAIT FOR 1 ns;
        cpu_assert_read(x"feed_feed");
        wbp_assert_read_pending(x"feed_feed");
        teardown;

        -- Back-to-back write request to different slave.
        cpu_write(x"fefe_fefe", x"0000_0001");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"fefe_fefe", x"0000_0001");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_write;
        WAIT FOR 1 ns;
        cpu_assert_write;
        wbp_assert_write_pending(x"fefe_fefe", x"0000_0001");
        WAIT UNTIL rising_edge(clk);
        wbp_clear;
        cpu_write(x"bbbb_bbbb", x"0000_0002"); -- start of second write, different slave
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_idle;
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"bbbb_bbbb", x"0000_0002");
        WAIT UNTIL rising_edge(clk);
        wbp_ack_write;
        WAIT FOR 1 ns;
        cpu_assert_write;
        wbp_assert_write_pending(x"bbbb_bbbb", x"0000_0002");
        teardown;

        -- Atomic Op: Lone SC.
        cpu_sc(x"1000_0000", x"1234_5678");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_idle; -- is blocked
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_sc_failure;
        wbp_assert_idle;
        teardown;

        -- Atomic Op: LR and SC pair.
        cpu_lr(x"2000_0000");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"2000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_read(x"abcd_ef01");
        WAIT FOR 1 ns;
        cpu_assert_read(x"abcd_ef01");
        wbp_assert_read_pending(x"2000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_sc(x"2000_0000", x"1234_5678");
        wbp_clear;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"2000_0000", x"1234_5678");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write_pending(x"2000_0000", x"1234_5678");
        WAIT UNTIL rising_edge(clk);
        wbp_ack_write;
        WAIT FOR 1 ns;
        cpu_assert_sc_success;
        wbp_assert_write_pending(x"2000_0000", x"1234_5678");
        teardown;

        -- Atomic Op: LR and SC pair with mismatched address.
        cpu_lr(x"3000_0000");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"3000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_read(x"fedc_ba98");
        WAIT FOR 1 ns;
        cpu_assert_read(x"fedc_ba98");
        wbp_assert_read_pending(x"3000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_sc(x"3000_0004", x"9876_5432");
        wbp_clear;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_idle;
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_sc_failure;
        wbp_assert_idle;
        teardown;

        -- Atomic Op: Interrupted LR and SC pair.
        cpu_lr(x"4000_0000");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"4000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_read(x"1111_2222");
        WAIT FOR 1 ns;
        cpu_assert_read(x"1111_2222");
        wbp_assert_read_pending(x"4000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_read(x"5000_0000"); -- interrupting read
        wbp_clear;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read_pending(x"5000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_idle;
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"5000_0000");
        WAIT UNTIL rising_edge(clk);
        wbp_ack_read(x"3333_4444");
        WAIT FOR 1 ns;
        cpu_assert_read(x"3333_4444");
        wbp_assert_read_pending(x"5000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_sc(x"4000_0000", x"5555_6666");
        wbp_clear;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_idle;
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_idle;
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        cpu_assert_sc_failure;
        wbp_assert_idle;
        teardown;

        -- Atomic Op: LR with error.
        cpu_lr(x"6000_0000");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"6000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_err;
        WAIT FOR 1 ns;
        cpu_assert_err;
        wbp_assert_read_pending(x"6000_0000");
        teardown;

        -- Atomic Op: LR and SC pair with error on the SC.
        cpu_lr(x"7000_0000");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"7000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_read(x"7777_8888");
        WAIT FOR 1 ns;
        cpu_assert_read(x"7777_8888");
        wbp_assert_read_pending(x"7000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_sc(x"7000_0000", x"9999_aaaa");
        wbp_clear;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write(x"7000_0000", x"9999_aaaa");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_write_pending(x"7000_0000", x"9999_aaaa");
        WAIT UNTIL rising_edge(clk);
        wbp_err;
        WAIT FOR 1 ns;
        cpu_assert_err;
        wbp_assert_write_pending(x"7000_0000", x"9999_aaaa");
        teardown;

        -- Atomic Op: Interrupted LR and SC pair with error on the interrupter.
        cpu_lr(x"8000_0000");
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"8000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        wbp_ack_read(x"bbbb_cccc");
        WAIT FOR 1 ns;
        cpu_assert_read(x"bbbb_cccc");
        wbp_assert_read_pending(x"8000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_read(x"9000_0000"); -- interrupting read
        wbp_clear;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read_pending(x"9000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_idle;
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_read(x"9000_0000");
        WAIT UNTIL rising_edge(clk);
        wbp_err;
        WAIT FOR 1 ns;
        cpu_assert_err;
        wbp_assert_read_pending(x"9000_0000");
        WAIT UNTIL rising_edge(clk);
        cpu_sc(x"8000_0000", x"dddd_eeee");
        wbp_clear;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_idle;
        WAIT UNTIL rising_edge(clk);
        cpu_clear_stb;
        WAIT FOR 1 ns;
        cpu_assert_idle;
        wbp_assert_idle;
        WAIT UNTIL rising_edge(clk);
        WAIT FOR 1 ns;
        cpu_assert_sc_failure;
        wbp_assert_idle;
        teardown;

        -- Report successful test.
        REPORT "Test OK";
        tb_done <= '1';
        WAIT;
    END PROCESS test;

    -- Check properties of wishbone interface that shall always be valid.
    wbp_check : PROCESS (clk) IS
    BEGIN
        IF rising_edge(clk) THEN
            -- stb can only ever be '1' when cyc is also '1'
            IF wbp_mosi.stb = '1' THEN
                ASSERT wbp_mosi.cyc = '1'
                REPORT "stb without cyc"
                    SEVERITY failure;
            END IF;

            -- never generate simultaneous ack and err
            ASSERT rstn = '0' OR (wbp_miso.ack AND wbp_miso.err) = '0'
            REPORT "simultaneous ack and err"
                SEVERITY failure;

            -- only ever generate ack/err during valid cyc
            IF (wbp_miso.ack OR wbp_miso.err) = '1' THEN
                ASSERT wbp_mosi.cyc = '1'
                REPORT "ack/err without cyc"
                    SEVERITY failure;
            END IF;

            -- never immediately ack/err on stb
            IF wbp_mosi.stb = '1' THEN
                ASSERT (wbp_miso.ack OR wbp_miso.err) = '0'
                REPORT "simultaneous stb and ack/err"
                    SEVERITY failure;
            END IF;

            -- count pending requests
            IF wbp_mosi.stb = '1' AND wbp_miso.stall = '0' THEN
                wbp_pending <= wbp_pending + 1;
            ELSIF (wbp_miso.ack OR wbp_miso.err) = '1' THEN
                wbp_pending <= wbp_pending - 1;
            END IF;

            -- only ever generate ack/err after requested by stb
            -- also never more than one request pending
            ASSERT wbp_pending = 0 OR wbp_pending = 1
            REPORT "missmatch of stb and ack/err"
                SEVERITY failure;
        END IF;
    END PROCESS wbp_check;

    -- Check properties of cpu interface that shall always be valid.
    cpu_check : PROCESS (clk) IS
    BEGIN
        IF rising_edge(clk) THEN
            -- never receive simultaneous ack and err
            ASSERT rstn = '0' OR (rsp.ack AND rsp.err) = '0'
            REPORT "simultaneous ack and err"
                SEVERITY failure;

            -- never immediately ack/err on stb
            IF req.stb = '1' THEN
                ASSERT (rsp.ack OR rsp.err) = '0'
                REPORT "simultaneous stb and ack/err"
                    SEVERITY failure;
            END IF;

            -- count pending requests
            IF req.stb = '1' THEN
                cpu_pending <= cpu_pending + 1;
            ELSIF (rsp.ack OR rsp.err) = '1' THEN
                cpu_pending <= cpu_pending - 1;
            END IF;

            -- only ever generate ack/err during valid request
            IF (rsp.ack OR rsp.err) = '1' THEN
                ASSERT cpu_pending = 1
                REPORT "ack/err without active request"
                    SEVERITY failure;
            END IF;

            -- only ever receive ack/err after requested by stb
            -- also never more than one request pending
            ASSERT cpu_pending = 0 OR cpu_pending = 1
            REPORT "missmatch of stb and ack/err"
                SEVERITY failure;
        END IF;
    END PROCESS cpu_check;

END ARCHITECTURE simulation;
