-- =============================================================================
-- File:                    wb_riscv_clint_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  wb_riscv_clint_tb
--
-- Description:             Testbench for the CLINT 'wb_riscv_clint'.
--
-- Changes:                 0.1, 2023-08-22, leuen4
--                              initial version
--                          0.2, 2023-08-24, leuen4
--                              test writing to MTIME register
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_riscv_clint_tb IS
    -- Testbench needs no ports.
END ENTITY wb_riscv_clint_tb;

ARCHITECTURE simulation OF wb_riscv_clint_tb IS

    -- Signals for sequential DUTs.
    CONSTANT CLK_PERIOD : DELAY_LENGTH := 20 ns; -- 50 MHz
    SIGNAL clk : STD_LOGIC := '1';
    SIGNAL rstn : STD_LOGIC := '0';
    SIGNAL tb_done : STD_LOGIC := '0'; -- flag end of tests

    -- Signals for connecting to the DUT.
    SIGNAL wb_slave_rx : wb_req_sig_t := (
        adr => (OTHERS => '0'), dat => (OTHERS => '0'), we => '0',
        sel => (OTHERS => '0'), stb => '0', cyc => '0'
    );
    SIGNAL wb_slave_tx : wb_resp_sig_t;
    SIGNAL mtime_irq : STD_ULOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL msw_irq : STD_ULOGIC_VECTOR(1 DOWNTO 0);

BEGIN

    -- Instantiate the device under test.
    dut : ENTITY work.wb_riscv_clint
        GENERIC MAP(
            N_HARTS => 2 -- number of HARTs
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk,  -- global clock, rising edge
            rstn_i => rstn, -- global reset, low-active, syn
            -- Wishbone slave interface --
            wb_slave_i => wb_slave_rx,
            wb_slave_o => wb_slave_tx,
            -- IRQs --
            mtime_irq_o => mtime_irq, -- machine timer interrupt
            msw_irq_o   => msw_irq    -- machine software interrupt
        );

    -- Clock that stops after all tests are done.
    clk <= '0' WHEN tb_done = '1' ELSE
        NOT clk AFTER 0.5 * CLK_PERIOD;

    -- Power on reset the DUT, lasts two clock cycles.
    rstn <= '0', '1' AFTER 2 * CLK_PERIOD;

    test : PROCESS IS
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(clk);
        WAIT UNTIL rising_edge(clk);

        -- After POR all timer IRQs should fire as cmp was reset to 0.
        ASSERT mtime_irq = "11"
        REPORT "Expected all timer interrupts to be high!"
            SEVERITY failure;

        -- After POR all software IRQs should be reset.
        ASSERT msw_irq = "00"
        REPORT "Expected all software interrupts to be low!"
            SEVERITY failure;

        -- Configure MTIMECMP.lo of HART 0
        wb_sim_write32(clk, wb_slave_rx, wb_slave_tx, x"0000_4000", STD_ULOGIC_VECTOR(to_unsigned(32, WB_DATA_WIDTH)));
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_4000", STD_ULOGIC_VECTOR(to_unsigned(32, WB_DATA_WIDTH)));
        WAIT UNTIL rising_edge(clk);
        -- IRQ should now be reset.
        ASSERT mtime_irq(0) = '0'
        REPORT "Expected first timer interrupt to be reset!"
            SEVERITY failure;
        -- Wait a bit, IRQ should now be set.
        WAIT FOR 32 * CLK_PERIOD;
        ASSERT mtime_irq(0) = '1'
        REPORT "Expected first timer interrupt to be set!"
            SEVERITY failure;
        -- Configure MTIMECMP.hi of HART 0
        wb_sim_write32(clk, wb_slave_rx, wb_slave_tx, x"0000_4004", STD_ULOGIC_VECTOR(to_unsigned(1, WB_DATA_WIDTH)));
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_4004", STD_ULOGIC_VECTOR(to_unsigned(1, WB_DATA_WIDTH)));
        WAIT UNTIL rising_edge(clk);
        -- IRQ should now be reset.
        ASSERT mtime_irq(0) = '0'
        REPORT "Expected first timer interrupt to be reset!"
            SEVERITY failure;

        -- Configure MTIMECMP.lo of HART 1
        wb_sim_write32(clk, wb_slave_rx, wb_slave_tx, x"0000_4008", STD_ULOGIC_VECTOR(to_unsigned(64, WB_DATA_WIDTH)));
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_4008", STD_ULOGIC_VECTOR(to_unsigned(64, WB_DATA_WIDTH)));
        WAIT UNTIL rising_edge(clk);
        -- IRQ should now be reset.
        ASSERT mtime_irq(1) = '0'
        REPORT "Expected second timer interrupt to be reset!"
            SEVERITY failure;
        -- Wait a bit, IRQ should now be set.
        WAIT FOR 64 * CLK_PERIOD;
        ASSERT mtime_irq(1) = '1'
        REPORT "Expected second timer interrupt to be set!"
            SEVERITY failure;
        -- Configure MTIMECMP.hi of HART 1
        wb_sim_write32(clk, wb_slave_rx, wb_slave_tx, x"0000_400c", STD_ULOGIC_VECTOR(to_unsigned(1, WB_DATA_WIDTH)));
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_400c", STD_ULOGIC_VECTOR(to_unsigned(1, WB_DATA_WIDTH)));
        WAIT UNTIL rising_edge(clk);
        -- IRQ should now be reset.
        ASSERT mtime_irq(1) = '0'
        REPORT "Expected second timer interrupt to be reset!"
            SEVERITY failure;

        -- Set MSIP of HART 0.
        wb_sim_write32(clk, wb_slave_rx, wb_slave_tx, x"0000_0000", x"0000_0001");
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_0000", x"0000_0001");
        WAIT UNTIL rising_edge(clk);
        -- Software IRQ should be set.
        ASSERT msw_irq(0) = '1'
        REPORT "Expected first software interrupt to be set!"
            SEVERITY failure;
        -- Reset MSIP of HART 0.
        wb_sim_write32(clk, wb_slave_rx, wb_slave_tx, x"0000_0000", x"0000_0000");
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_0000", x"0000_0000");
        WAIT UNTIL rising_edge(clk);
        -- Software IRQ should be reset.
        ASSERT msw_irq(0) = '0'
        REPORT "Expected first software interrupt to be reset!"
            SEVERITY failure;

        -- Set MSIP of HART 1.
        wb_sim_write32(clk, wb_slave_rx, wb_slave_tx, x"0000_0004", x"0000_0001");
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_0004", x"0000_0001");
        WAIT UNTIL rising_edge(clk);
        -- Software IRQ should be set.
        ASSERT msw_irq(1) = '1'
        REPORT "Expected second software interrupt to be set!"
            SEVERITY failure;
        -- Reset MSIP of HART 1.
        wb_sim_write32(clk, wb_slave_rx, wb_slave_tx, x"0000_0004", x"0000_0000");
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_0004", x"0000_0000");
        WAIT UNTIL rising_edge(clk);
        -- Software IRQ should be reset.
        ASSERT msw_irq(1) = '0'
        REPORT "Expected second software interrupt to be reset!"
            SEVERITY failure;

        -- MTIME (hi + lo) should be some empirically found value.
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_bff8", x"0000_008a");
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_bffc", x"0000_0000");
        -- MTIME should have been incremented, value empirically found.
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_bff8", x"0000_008e");
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_bffc", x"0000_0000");
        -- MTIME.lo can be written and overflows afterwards.
        wb_sim_write32(clk, wb_slave_rx, wb_slave_tx, x"0000_bff8", x"ffff_ffff");
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_bff8", x"0000_0000");
        -- MTIME.hi did increment and can be reset.
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_bffc", x"0000_0001");
        wb_sim_write32(clk, wb_slave_rx, wb_slave_tx, x"0000_bffc", x"0000_0000");
        wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_bffc", x"0000_0000");

        -- Report successful test.
        REPORT "Test OK";
        tb_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
