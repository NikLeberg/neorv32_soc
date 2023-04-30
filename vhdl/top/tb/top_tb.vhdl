-- =============================================================================
-- File:                    top_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  top_tb
--
-- Description:             Testbench for the whole top entity.
--
-- Changes:                 0.1, 2023-02-15, leuen4
--                              initial version
--                          0.2, 2023-02-28, leuen4
--                              change implementation of top if simulating
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY top_tb IS
    -- Testbench needs no ports.
END ENTITY top_tb;

ARCHITECTURE simulation OF top_tb IS
    -- Component definition for device under test.
    COMPONENT top IS
        GENERIC (
            SIMULATION : BOOLEAN := FALSE -- running in simulation?
        );
        PORT (
            -- Global control --
            clk_i  : IN STD_ULOGIC; -- global clock, rising edge
            rstn_i : IN STD_ULOGIC; -- global reset, low-active, async
            -- JTAG --
            altera_reserved_tck : IN STD_ULOGIC;
            altera_reserved_tms : IN STD_ULOGIC;
            altera_reserved_tdi : IN STD_ULOGIC;
            altera_reserved_tdo : OUT STD_ULOGIC;
            -- FLASH (plain SPI or XIP execute in place via SPI) --
            flash_csn_o   : OUT STD_ULOGIC;        -- chip-select, low-active
            flash_holdn_o : OUT STD_ULOGIC := 'H'; -- hold serial communication, low-active
            flash_clk_o   : OUT STD_ULOGIC;        -- serial clock
            flash_sdi_o   : OUT STD_ULOGIC;        -- flash data input
            flash_sdo_i   : IN STD_ULOGIC;         -- flash data output
            flash_wpn_o   : OUT STD_ULOGIC := 'H'; -- write-protect, low-active
            -- GPIO --
            gpio0_o : OUT STD_ULOGIC_VECTOR(7 DOWNTO 0); -- parallel output
            gpio1_o : OUT STD_ULOGIC_VECTOR(7 DOWNTO 0); -- parallel output
            gpio2_o : OUT STD_ULOGIC_VECTOR(7 DOWNTO 0); -- parallel output
            gpio3_o : OUT STD_ULOGIC_VECTOR(7 DOWNTO 0); -- parallel output
            gpio4_o : OUT STD_ULOGIC_VECTOR(7 DOWNTO 0); -- parallel output
            -- UART0 --
            uart0_txd_o : OUT STD_ULOGIC; -- UART0 send data
            uart0_rxd_i : IN STD_ULOGIC;  -- UART0 receive data
            -- SDRAM --
            sdram_addr  : OUT UNSIGNED(12 DOWNTO 0);                              -- addr
            sdram_ba    : OUT UNSIGNED(1 DOWNTO 0);                               -- ba
            sdram_n_cas : OUT STD_LOGIC;                                          -- cas_n
            sdram_cke   : OUT STD_LOGIC;                                          -- cke
            sdram_n_cs  : OUT STD_LOGIC;                                          -- cs_n
            sdram_d     : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => 'X'); -- dq
            sdram_dqm   : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);                       -- dqm
            sdram_n_ras : OUT STD_LOGIC;                                          -- ras_n
            sdram_n_we  : OUT STD_LOGIC;                                          -- we_n
            sdram_clk   : OUT STD_LOGIC                                           -- clk
        );
    END COMPONENT top;

    -- Signals for sequential DUTs.
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';

    -- Signals for connecting to the DUT.
    SIGNAL s_gpio0_o : STD_ULOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL s_uart_tx_o : STD_LOGIC;

BEGIN
    -- Instantiate the device under test.
    dut : top
    GENERIC MAP(
        SIMULATION => true
    )
    PORT MAP(
        clk_i               => s_clock,
        rstn_i              => s_n_reset,
        gpio0_o             => s_gpio0_o,
        altera_reserved_tck => '0',
        altera_reserved_tms => '0',
        altera_reserved_tdi => '0',
        flash_sdo_i         => '0',
        uart0_rxd_i         => '1',
        uart0_txd_o         => s_uart_tx_o
    );

    -- Clock with 50 MHz.
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 10 ns;

    -- Power on reset the DUT, lasts two clock cycles.
    s_n_reset <= '0', '1' AFTER 40 ns;

    test : PROCESS IS
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(s_clock);

        -- Each hart tries to blink its respective LED on gpio0.
        -- Check that hart0 is able to blink it a few times.

        FOR i IN 0 TO 3 LOOP
            -- Wait for LSB gpio bit to go high.
            WAIT UNTIL s_gpio0_o(0) = '1' FOR 1 ms;
            ASSERT s_gpio0_o(0) = '1'
            REPORT "LED0 was not observed to go high, did hart0 run?"
                SEVERITY failure;

            -- Wait for LSB gpio bit to go low.
            WAIT UNTIL s_gpio0_o(0) = '0' FOR 1 ms;
            ASSERT s_gpio0_o(0) = '0'
            REPORT "LED0 was not observed to go low, did hart0 run?"
                SEVERITY failure;
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
