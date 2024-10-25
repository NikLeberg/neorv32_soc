-- =============================================================================
-- File:                    wb_gcd_tb.vhdl
--
-- Entity:                  wb_gcd_tb
--
-- Description:             Testbench for the wishbone wrapper 'wb_gcd' around
--                          the basic 'gcd' entity.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.1
--
-- Changes:                 0.1, 2023-02-28, NikLeberg
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_gcd_tb IS
    -- Testbench needs no ports.
END ENTITY wb_gcd_tb;

ARCHITECTURE simulation OF wb_gcd_tb IS
    -- Component definition for device under test.
    COMPONENT wb_gcd IS
        PORT (
            -- Global control --
            clk_i  : IN STD_ULOGIC; -- global clock, rising edge
            rstn_i : IN STD_ULOGIC; -- global reset, low-active, asyn
            -- Wishbone slave interface --
            wb_slave_i : IN wb_req_sig_t;
            wb_slave_o : OUT wb_resp_sig_t
        );
    END COMPONENT wb_gcd;

    -- Signals for sequential DUTs.
    CONSTANT CLK_PERIOD : DELAY_LENGTH := 20 ns; -- 50 MHz
    SIGNAL clk : STD_LOGIC := '1';
    SIGNAL rstn : STD_LOGIC := '0';
    SIGNAL tb_done : STD_LOGIC := '0'; -- flag end of tests

    -- Signals for connecting to the DUT.
    SIGNAL wb_slave_rx : wb_req_sig_t;
    SIGNAL wb_slave_tx : wb_resp_sig_t;

BEGIN
    -- Instantiate the device under test.
    dut : wb_gcd
    PORT MAP(
        -- Global control --
        clk_i  => clk,  -- global clock, rising edge
        rstn_i => rstn, -- global reset, low-active, asyn
        -- Wishbone slave interface --
        wb_slave_i => wb_slave_rx,
        wb_slave_o => wb_slave_tx
    );

    -- Clock that stops after all tests are done.
    clk <= '0' WHEN tb_done = '1' ELSE
        NOT clk AFTER 0.5 * CLK_PERIOD;

    -- Power on reset the DUT, lasts two clock cycles.
    rstn <= '0', '1' AFTER 2 * CLK_PERIOD;

    test : PROCESS IS
        -- Procedure that generates stimuli in form of wishbone read / write
        -- transactions for the DUT. The returned gcd values as well as wishbone
        -- bus conformity is checked.
        PROCEDURE check (
            CONSTANT a, b, result : INTEGER -- values for GCD algorithm
        ) IS
        BEGIN
            -- Write dataa register.
            wb_sim_write32(clk, wb_slave_rx, wb_slave_tx, x"0000_0000", STD_ULOGIC_VECTOR(to_unsigned(a, WB_DATA_WIDTH)));
            -- Write datab register.
            wb_sim_write32(clk, wb_slave_rx, wb_slave_tx, x"0000_0004", STD_ULOGIC_VECTOR(to_unsigned(b, WB_DATA_WIDTH)));
            -- GCD calculation should have been triggered, but not calculated
            -- already. Check if result is teporarily set to an invalid value.
            wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_0008", x"ffff_ffff");
            -- Use the fact that the result is always ready at the output to check
            -- when calculation is finished.
            WAIT ON wb_slave_tx.dat;
            -- Check result of GCD calculation.
            wb_sim_read32(clk, wb_slave_rx, wb_slave_tx, x"0000_0008", STD_ULOGIC_VECTOR(to_unsigned(result, WB_DATA_WIDTH)));
        END PROCEDURE check;

    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(clk);

        -- Check a few fixed combinations of inputs & expected outputs.
        check(15, 5, 5);
        check(100, 50, 50);
        check(9, 6, 3);
        check(294, 546, 42);
        check(123456789, 847695, 3);

        -- Report successful test.
        REPORT "Test OK";
        tb_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
