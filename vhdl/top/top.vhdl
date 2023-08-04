-- =============================================================================
-- File:                    top.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.5
--
-- Entity:                  top
--
-- Description:             Toplevel entity for SoC project based on NEORV32.
--
-- Changes:                 0.1, 2023-01-16, leuen4
--                              initial version
--                          0.2, 2023-02-25, leuen4
--                              implement IMEM with SDRAM
--                          0.3, 2023-02-28, leuen4
--                              disable SDRAM and JTAG if simulating
--                          0.4, 2023-04-16, leuen4
--                              replace simple bus mux with crossbar
--                          0.5, 2023-04-23, leuen4
--                              remove GCD parts and build SMP system
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

USE work.wb_pkg.ALL;

ENTITY top IS
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
        sdram_addr  : OUT UNSIGNED(12 DOWNTO 0);                               -- addr
        sdram_ba    : OUT UNSIGNED(1 DOWNTO 0);                                -- ba
        sdram_n_cas : OUT STD_ULOGIC;                                          -- cas_n
        sdram_cke   : OUT STD_ULOGIC;                                          -- cke
        sdram_n_cs  : OUT STD_ULOGIC;                                          -- cs_n
        sdram_d     : INOUT STD_ULOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => 'X'); -- dq
        sdram_dqm   : OUT STD_ULOGIC_VECTOR(1 DOWNTO 0);                       -- dqm
        sdram_n_ras : OUT STD_ULOGIC;                                          -- ras_n
        sdram_n_we  : OUT STD_ULOGIC;                                          -- we_n
        sdram_clk   : OUT STD_ULOGIC                                           -- clk
    );
END ENTITY top;

ARCHITECTURE top_arch OF top IS

    COMPONENT cycloneive_jtag
        GENERIC (
            lpm_type : STRING := "cycloneive_jtag"
        );
        PORT (
            tms         : IN STD_LOGIC := '0';
            tck         : IN STD_LOGIC := '0';
            tdi         : IN STD_LOGIC := '0';
            tdoutap     : IN STD_LOGIC := '0';
            tdouser     : IN STD_LOGIC := '0';
            tdo         : OUT STD_LOGIC;
            tmsutap     : OUT STD_LOGIC;
            tckutap     : OUT STD_LOGIC;
            tdiutap     : OUT STD_LOGIC;
            shiftuser   : OUT STD_LOGIC;
            clkdruser   : OUT STD_LOGIC;
            updateuser  : OUT STD_LOGIC;
            runidleuser : OUT STD_LOGIC;
            usr1user    : OUT STD_LOGIC
        );
    END COMPONENT;

    CONSTANT CLOCK_FREQUENCY : POSITIVE := 50000000; -- clock frequency of clk_i in Hz
    CONSTANT NUM_HARTS : POSITIVE := 5; -- number of implemented harts i.e. CPUs

    SIGNAL con_jtag_tck, con_jtag_tdi, con_jtag_tdo, con_jtag_tms : STD_LOGIC;

    SIGNAL con_gpio_o : STD_ULOGIC_VECTOR(63 DOWNTO 0);
    SIGNAL con_dummy_spi_csn : STD_ULOGIC_VECTOR(6 DOWNTO 0);

    -- Wishbone interface signals
    CONSTANT WB_N_MASTERS : NATURAL := 2 * NUM_HARTS;
    CONSTANT WB_N_SLAVES : NATURAL := 4;
    CONSTANT WB_MEMORY_MAP : wb_map_t :=
    (
    (x"0000_0000", 32 * 1024), -- IMEM, 32 KB (port a)
    (x"0000_0000", 32 * 1024), -- IMEM, 32 KB (port b)
    (x"8000_0000", 32 * 1024 * 1024), -- SDRAM, 32 MB
    (base_io_gpio_c, iodev_size_c) -- NEORV32 GPIO, 4 words
    );
    SIGNAL wb_masters_o : wb_master_tx_arr_t(WB_N_MASTERS - 1 DOWNTO 0);
    SIGNAL wb_masters_i : wb_master_rx_arr_t(WB_N_MASTERS - 1 DOWNTO 0);
    SIGNAL wb_slaves_i : wb_slave_rx_arr_t(WB_N_SLAVES - 1 DOWNTO 0);
    SIGNAL wb_slaves_o : wb_slave_tx_arr_t(WB_N_SLAVES - 1 DOWNTO 0);
    -- Error slave to terminate accesses that have no associated slave.
    CONSTANT wb_slave_err_o : wb_master_rx_sig_t := (ack => '0', err => '1', dat => (OTHERS => '0'));
    SIGNAL wb_slave_dummy : wb_master_rx_sig_t;

    -- Change behaviour when simulating:
    --  > do not implement external sdram and replace with internal dmem
    --  > do not implement altera specific jtag atom
    CONSTANT IMPLEMENT_SDRAM : BOOLEAN := NOT SIMULATION;
    CONSTANT IMPLEMENT_DMEM : BOOLEAN := SIMULATION;
    CONSTANT IMPLEMENT_JTAG : BOOLEAN := NOT SIMULATION;
    CONSTANT IMPLEMENT_ICACHE : BOOLEAN := (NUM_HARTS > 2);

BEGIN

    -- The Core Of The Problem ----------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    neorv32_cpu_smp_inst : ENTITY work.neorv32_cpu_smp
        GENERIC MAP(
            -- General --
            CLOCK_FREQUENCY   => CLOCK_FREQUENCY, -- clock frequency of clk_i in Hz
            NUM_HARTS         => NUM_HARTS,       -- number of implemented harts i.e. CPUs
            INT_BOOTLOADER_EN => false,           -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM
            -- Internal Instruction Cache (iCACHE) --
            ICACHE_EN => IMPLEMENT_ICACHE -- implement instruction cache
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,  -- global clock, rising edge
            rstn_i => rstn_i, -- global reset, low-active, async
            -- Wishbone instruction bus interface(s), two per hart --
            wb_master_o => wb_masters_o(2 * NUM_HARTS - 1 DOWNTO 0), -- control and data from master to slave
            wb_master_i => wb_masters_i(2 * NUM_HARTS - 1 DOWNTO 0), -- status and data from slave to master
            -- Advanced memory control signals --
            fence_o  => OPEN, -- indicates an executed FENCE operation
            fencei_o => OPEN, -- indicates an executed FENCEI operation
            -- CPU interrupts --
            mti_i => (OTHERS => '0'), -- machine timer interrupt, available if IO_MTIME_EN = false
            msi_i => (OTHERS => '0'), -- machine software interrupt
            mei_i => (OTHERS => '0')  -- machine external interrupt
        );

    -- NEORV32 IO Modules ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    neorv32_wb_gpio_inst : ENTITY work.neorv32_wb_gpio
        GENERIC MAP(
            GPIO_NUM => 8 -- number of GPIO input/output pairs (0..64)
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,  -- global clock, rising edge
            rstn_i => rstn_i, -- global reset, low-active, async
            -- Wishbone slave interface --
            wb_slave_i => wb_slaves_i(3), -- control and data from master to slave
            wb_slave_o => wb_slaves_o(3), -- status and data from slave to master
            -- parallel io --
            gpio_o => con_gpio_o,
            gpio_i => (OTHERS => '0')
        );

    -- GPIO output --
    gpio0_o <= con_gpio_o(7 DOWNTO 0);

    -- JTAG atom --
    gen_jtag : IF IMPLEMENT_JTAG = TRUE GENERATE
        jtag_inst : cycloneive_jtag
        PORT MAP(
            tms         => altera_reserved_tms,
            tck         => altera_reserved_tck,
            tdi         => altera_reserved_tdi,
            tdo         => altera_reserved_tdo,
            tdouser     => con_jtag_tdo,
            tmsutap     => con_jtag_tms,
            tckutap     => con_jtag_tck,
            tdiutap     => con_jtag_tdi,
            shiftuser   => OPEN, -- don't care, dtm has it's own JTAG FSM
            clkdruser   => OPEN,
            updateuser  => OPEN,
            runidleuser => OPEN,
            usr1user    => OPEN
        );
    END GENERATE;

    -- Wishbone interconnect --
    wb_crossbar_inst : ENTITY work.wb_crossbar
        GENERIC MAP(
            -- General --
            N_MASTERS  => WB_N_MASTERS, -- number of connected masters
            N_SLAVES   => WB_N_SLAVES,  -- number of connected slaves
            N_OTHERS   => 1,            -- number of interfaces for other slaves not in memory map
            MEMORY_MAP => WB_MEMORY_MAP -- memory map of address space
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,  -- global clock, rising edge
            rstn_i => rstn_i, -- global reset, low-active, asyn
            -- Wishbone master interface --
            wb_masters_i => wb_masters_o,
            wb_masters_o => wb_masters_i,
            -- Wishbone slave interface(s) --
            wb_slaves_o => wb_slaves_i,
            wb_slaves_i => wb_slaves_o,
            -- Other unmapped Wishbone slave interface(s) --
            wb_other_slaves_o    => OPEN,
            wb_other_slaves_i(0) => wb_slave_err_o
        );

    -- IMEM dual-port ROM --
    wb_imem_inst : ENTITY work.wb_imem
        GENERIC MAP(
            IMEM_SIZE => 1 * 1024 -- size of instruction memory in bytes
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,  -- global clock, rising edge
            rstn_i => rstn_i, -- global reset, low-active, asyn
            -- Wishbone slave interfaces --
            wb_slaves_i => wb_slaves_i(1 DOWNTO 0), -- control and data from master to slave
            wb_slaves_o => wb_slaves_o(1 DOWNTO 0)  -- status and data from slave to master
        );

    -- SDRAM Controller --
    gen_sdram : IF IMPLEMENT_SDRAM = TRUE GENERATE
        wb_sdram_inst : ENTITY work.wb_sdram
            GENERIC MAP(
                -- General --
                CLOCK_FREQUENCY => CLOCK_FREQUENCY -- clock frequency of clk_i in Hz
            )
            PORT MAP(
                -- Global control --
                clk_i  => clk_i,  -- global clock, rising edge
                rstn_i => rstn_i, -- global reset, low-active, asyn
                -- Wishbone slave interface --
                wb_slave_i => wb_slaves_i(2),
                wb_slave_o => wb_slaves_o(2),
                -- SDRAM --
                sdram_addr  => sdram_addr,  -- addr
                sdram_ba    => sdram_ba,    -- ba
                sdram_n_cas => sdram_n_cas, -- cas_n
                sdram_cke   => sdram_cke,   -- cke
                sdram_n_cs  => sdram_n_cs,  -- cs_n
                sdram_d     => sdram_d,     -- dq
                sdram_dqm   => sdram_dqm,   -- dqm
                sdram_n_ras => sdram_n_ras, -- ras_n
                sdram_n_we  => sdram_n_we,  -- we_n
                sdram_clk   => sdram_clk    -- clk
            );
    END GENERATE;

    -- DRAM --
    gen_dmem : IF IMPLEMENT_DMEM = TRUE GENERATE
        gen_syn : IF SIMULATION = FALSE GENERATE
            wb_dmem_inst : ENTITY work.wb_dmem(synthesis)
                GENERIC MAP(
                    DMEM_SIZE => 32 * 1024 -- size of data memory in bytes
                )
                PORT MAP(
                    -- Global control --
                    clk_i  => clk_i,  -- global clock, rising edge
                    rstn_i => rstn_i, -- global reset, low-active, asyn
                    -- Wishbone slave interfaces --
                    wb_slaves_i(0) => wb_slaves_i(2), -- control and data from master to slave
                    wb_slaves_i(1) => (cyc => '0', stb => '0', we => '0', sel => (OTHERS => '0'), adr => (OTHERS => '0'), dat => (OTHERS => '0')),
                    wb_slaves_o(0) => wb_slaves_o(2), -- status and data from slave to master
                    wb_slaves_o(1) => wb_slave_dummy
                );
        END GENERATE;
        gen_sim : IF SIMULATION = TRUE GENERATE
            wb_dmem_inst : ENTITY work.wb_dmem(simulation)
                GENERIC MAP(
                    DMEM_SIZE => 32 * 1024 -- size of data memory in bytes
                )
                PORT MAP(
                    -- Global control --
                    clk_i  => clk_i,  -- global clock, rising edge
                    rstn_i => rstn_i, -- global reset, low-active, asyn
                    -- Wishbone slave interfaces --
                    wb_slaves_i(0) => wb_slaves_i(2), -- control and data from master to slave
                    wb_slaves_i(1) => (cyc => '0', stb => '0', we => '0', sel => (OTHERS => '0'), adr => (OTHERS => '0'), dat => (OTHERS => '0')),
                    wb_slaves_o(0) => wb_slaves_o(2), -- status and data from slave to master
                    wb_slaves_o(1) => wb_slave_dummy
                );
        END GENERATE;
    END GENERATE;

END ARCHITECTURE top_arch;
