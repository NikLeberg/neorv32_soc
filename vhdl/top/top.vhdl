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
    CONSTANT NUM_HARTS : POSITIVE := 4; -- number of implemented harts i.e. CPUs

    SIGNAL con_jtag_tck, con_jtag_tdi, con_jtag_tdo, con_jtag_tms : STD_LOGIC;
    SIGNAL con_gpio_o : STD_ULOGIC_VECTOR(63 DOWNTO 0);
    SIGNAL con_mti, con_msi : STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0);
    SIGNAL con_dci_ndmrstn : STD_ULOGIC;
    SIGNAL con_dci_halt_req : STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0);
    SIGNAL con_dci_cpu_debug : STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0);

    -- Wishbone interface signals
    -- The frequently accessed slaves go through the high speed crossbar which
    -- enables simultaneous connections. The less frequently ones are connected
    -- through a single and simple low speed mux.
    CONSTANT WB_N_MASTERS : NATURAL := 2 * NUM_HARTS;
    CONSTANT WB_N_SLAVES_CROSSBAR : NATURAL := 3;
    CONSTANT WB_N_SLAVES_MUX : NATURAL := 5;
    CONSTANT WB_MEMORY_MAP_CROSSBAR : wb_map_t :=
    (
    (x"0000_0000", 1 * 1024), -- IMEM, 1 KB (port a)
    (x"0000_0000", 1 * 1024), -- IMEM, 1 KB (port b)
    (x"8000_0000", 32 * 1024 * 1024) -- SDRAM, 32 MB
    );
    CONSTANT WB_MEMORY_MAP_MUX : wb_map_t :=
    (
    (x"f000_0000", 48 * 1024), -- CLINT, 48 KB (largely unused)
    (base_io_gpio_c, iodev_size_c), -- NEORV32 GPIO, 256 B
    (base_io_uart0_c, iodev_size_c), -- NEORV32 UART0, 256 B
    (base_io_sysinfo_c, iodev_size_c), -- NEORV32 SYSINFO, 256 B
    (base_io_dm_c, iodev_size_c) -- NEORV32 OCD, 256 B
    );
    SIGNAL wb_masters_req : wb_req_arr_t(WB_N_MASTERS - 1 DOWNTO 0);
    SIGNAL wb_masters_resp : wb_resp_arr_t(WB_N_MASTERS - 1 DOWNTO 0);
    SIGNAL wb_slaves_cross_req : wb_req_arr_t(WB_N_SLAVES_CROSSBAR - 1 DOWNTO 0);
    SIGNAL wb_slaves_cross_resp : wb_resp_arr_t(WB_N_SLAVES_CROSSBAR - 1 DOWNTO 0);
    SIGNAL wb_master_cross_req : wb_req_arr_t(0 DOWNTO 0);
    SIGNAL wb_master_cross_resp : wb_resp_arr_t(0 DOWNTO 0);
    SIGNAL wb_slaves_mux_req : wb_req_arr_t(WB_N_SLAVES_MUX - 1 DOWNTO 0);
    SIGNAL wb_slaves_mux_resp : wb_resp_arr_t(WB_N_SLAVES_MUX - 1 DOWNTO 0);
    -- Error slave to terminate accesses that have no associated slave.
    CONSTANT wb_slave_err_resp : wb_resp_sig_t := (ack => '0', err => '1', dat => (OTHERS => '0'));
    SIGNAL wb_slave_dummy_resp : wb_resp_sig_t;

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
            -- On-Chip Debugger (OCD) --
            ON_CHIP_DEBUGGER_EN => IMPLEMENT_JTAG, -- implement on-chip debugger
            -- Internal Instruction Cache (iCACHE) --
            ICACHE_EN => IMPLEMENT_ICACHE -- implement instruction cache
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,  -- global clock, rising edge
            rstn_i => rstn_i, -- global reset, low-active, async
            -- Wishbone instruction bus interface(s), two per hart --
            wb_master_o => wb_masters_req(2 * NUM_HARTS - 1 DOWNTO 0),  -- control and data from master to slave
            wb_master_i => wb_masters_resp(2 * NUM_HARTS - 1 DOWNTO 0), -- status and data from slave to master
            -- Advanced memory control signals --
            fence_o  => OPEN, -- indicates an executed FENCE operation
            fencei_o => OPEN, -- indicates an executed FENCEI operation
            -- CPU interrupts --
            mti_i => con_mti,         -- risc-v machine timer interrupt
            msi_i => con_msi,         -- risc-v machine software interrupt
            mei_i => (OTHERS => '0'), -- risc-v machine external interrupt
            -- debug core interface (DCI) --
            dci_ndmrstn_i   => con_dci_ndmrstn,  -- soc reset (all harts)
            dci_halt_req_i  => con_dci_halt_req, -- request hart to halt (enter debug mode)
            dci_cpu_debug_o => con_dci_cpu_debug -- cpu is in debug mode
        );

    -- Wishbone Interconnect (Crossbar + Mux) -------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    wb_crossbar_inst : ENTITY work.wb_crossbar
        GENERIC MAP(
            -- General --
            N_MASTERS  => WB_N_MASTERS,          -- number of connected masters
            N_SLAVES   => WB_N_SLAVES_CROSSBAR,  -- number of connected slaves
            N_OTHERS   => 1,                     -- number of interfaces for other slaves not in memory map
            MEMORY_MAP => WB_MEMORY_MAP_CROSSBAR -- memory map of address space
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,  -- global clock, rising edge
            rstn_i => rstn_i, -- global reset, low-active, asyn
            -- Wishbone master interface --
            wb_masters_i => wb_masters_req,
            wb_masters_o => wb_masters_resp,
            -- Wishbone slave interface(s) --
            wb_slaves_o => wb_slaves_cross_req,
            wb_slaves_i => wb_slaves_cross_resp,
            -- Other unmapped Wishbone slave interface(s) --
            wb_other_slaves_o => wb_master_cross_req,
            wb_other_slaves_i => wb_master_cross_resp
        );

    wb_mux_inst : ENTITY work.wb_mux
        GENERIC MAP(
            -- General --
            N_SLAVES   => WB_N_SLAVES_MUX,  -- number of connected slaves
            MEMORY_MAP => WB_MEMORY_MAP_MUX -- memory map of address space
        )
        PORT MAP(
            -- Wishbone master interface --
            wb_master_i => wb_master_cross_req(0),
            wb_master_o => wb_master_cross_resp(0),
            -- Wishbone slave interface(s) --
            wb_slaves_o => wb_slaves_mux_req,
            wb_slaves_i => wb_slaves_mux_resp
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
            wb_slaves_i => wb_slaves_cross_req(1 DOWNTO 0), -- control and data from master to slave
            wb_slaves_o => wb_slaves_cross_resp(1 DOWNTO 0) -- status and data from slave to master
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
                wb_slave_i => wb_slaves_cross_req(2),
                wb_slave_o => wb_slaves_cross_resp(2),
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
                    wb_slaves_i(0) => wb_slaves_cross_req(2), -- control and data from master to slave
                    wb_slaves_i(1) => (cyc => '0', stb => '0', we => '0', sel => (OTHERS => '0'), adr => (OTHERS => '0'), dat => (OTHERS => '0')),
                    wb_slaves_o(0) => wb_slaves_cross_resp(2), -- status and data from slave to master
                    wb_slaves_o(1) => wb_slave_dummy_resp
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
                    wb_slaves_i(0) => wb_slaves_cross_req(2), -- control and data from master to slave
                    wb_slaves_i(1) => (cyc => '0', stb => '0', we => '0', sel => (OTHERS => '0'), adr => (OTHERS => '0'), dat => (OTHERS => '0')),
                    wb_slaves_o(0) => wb_slaves_cross_resp(2), -- status and data from slave to master
                    wb_slaves_o(1) => wb_slave_dummy_resp
                );
        END GENERATE;
    END GENERATE;

    -- Core Local Interruptor (CLINT) --
    wb_riscv_clint_inst : ENTITY work.wb_riscv_clint
        GENERIC MAP(
            N_HARTS => NUM_HARTS -- number of HARTs
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,  -- global clock, rising edge
            rstn_i => rstn_i, -- global reset, low-active, asyn
            -- Wishbone slave interface --
            wb_slave_i => wb_slaves_mux_req(0),
            wb_slave_o => wb_slaves_mux_resp(0),
            -- IRQs --
            mtime_irq_o => con_mti, -- machine timer interrupt
            msw_irq_o   => con_msi  -- machine software interrupt
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
            wb_slave_i => wb_slaves_mux_req(1),  -- control and data from master to slave
            wb_slave_o => wb_slaves_mux_resp(1), -- status and data from slave to master
            -- parallel io --
            gpio_o => con_gpio_o,
            gpio_i => (OTHERS => '0')
        );

    -- GPIO output --
    gpio0_o <= con_gpio_o(7 DOWNTO 0);

    neorv32_wb_uart0_inst : ENTITY work.neorv32_wb_uart
        GENERIC MAP(
            SIM_LOG_FILE => "neorv32.uart0.sim_mode.text.out", -- name of SM mode's log file
            UART_RX_FIFO => 1,                                 -- RX fifo depth, has to be a power of two, min 1
            UART_TX_FIFO => 1                                  -- TX fifo depth, has to be a power of two, min 1
        )
        PORT MAP(
            clk_i       => clk_i,                 -- global clock line
            rstn_i      => rstn_i,                -- global reset line, low-active, async
            wb_slave_i  => wb_slaves_mux_req(2),  -- control and data from master to slave
            wb_slave_o  => wb_slaves_mux_resp(2), -- status and data from slave to master
            clkgen_en_o => OPEN,                  -- enable clock generator
            clkgen_i    => "00000000",
            uart_txd_o  => OPEN, -- serial TX line
            uart_rxd_i  => 'H',  -- serial RX line
            uart_rts_o  => OPEN, -- UART.RX ready to receive ("RTR"), low-active, optional
            uart_cts_i  => 'H',  -- UART.TX allowed to transmit, low-active, optional
            irq_rx_o    => OPEN, -- RX interrupt
            irq_tx_o    => OPEN  -- TX interrupt
        );

    neorv32_wb_sysinfo_inst : ENTITY work.neorv32_wb_sysinfo
        GENERIC MAP(
            -- General --
            CLOCK_FREQUENCY   => CLOCK_FREQUENCY, -- clock frequency of clk_i in Hz
            INT_BOOTLOADER_EN => false,           -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM
            -- Physical memory protection --
            PMP_NUM_REGIONS => 0, -- number of regions (0..64)
            -- Internal instruction memory --
            MEM_INT_IMEM_EN   => true,     -- implement processor-internal instruction memory
            MEM_INT_IMEM_SIZE => 1 * 1024, -- size of processor-internal instruction memory in bytes
            -- Internal data memory --
            MEM_INT_DMEM_EN   => false, -- implement processor-internal data memory
            MEM_INT_DMEM_SIZE => 0,     -- size of processor-internal data memory in bytes
            -- Reservation Set Granularity --
            AMO_RVS_GRANULARITY => 4, -- size in bytes, has to be a power of 2, min 4
            -- Instruction cache --
            ICACHE_EN            => IMPLEMENT_ICACHE, -- implement instruction cache
            ICACHE_NUM_BLOCKS    => 4,                -- i-cache: number of blocks (min 2), has to be a power of 2
            ICACHE_BLOCK_SIZE    => 64,               -- i-cache: block size in bytes (min 4), has to be a power of 2
            ICACHE_ASSOCIATIVITY => 1,                -- i-cache: associativity (min 1), has to be a power 2
            -- Data cache --
            DCACHE_EN         => false, -- implement data cache
            DCACHE_NUM_BLOCKS => 2,     -- d-cache: number of blocks (min 2), has to be a power of 2
            DCACHE_BLOCK_SIZE => 4,     -- d-cache: block size in bytes (min 4), has to be a power of 2
            -- External memory interface --
            MEM_EXT_EN         => true, -- implement external memory bus interface?
            MEM_EXT_BIG_ENDIAN => true, -- byte order: true=big-endian, false=little-endian
            -- On-chip debugger --
            ON_CHIP_DEBUGGER_EN => IMPLEMENT_JTAG, -- implement OCD?
            -- Processor peripherals --
            IO_GPIO_EN    => true,  -- implement general purpose IO port (GPIO)?
            IO_MTIME_EN   => true,  -- implement machine system timer (MTIME)?
            IO_UART0_EN   => true,  -- implement primary universal asynchronous receiver/transmitter (UART0)?
            IO_UART1_EN   => false, -- implement secondary universal asynchronous receiver/transmitter (UART1)?
            IO_SPI_EN     => false, -- implement serial peripheral interface (SPI)?
            IO_SDI_EN     => false, -- implement serial data interface (SDI)?
            IO_TWI_EN     => false, -- implement two-wire interface (TWI)?
            IO_PWM_EN     => false, -- implement pulse-width modulation controller (PWM)?
            IO_WDT_EN     => false, -- implement watch dog timer (WDT)?
            IO_TRNG_EN    => false, -- implement true random number generator (TRNG)?
            IO_CFS_EN     => false, -- implement custom functions subsystem (CFS)?
            IO_NEOLED_EN  => false, -- implement NeoPixel-compatible smart LED interface (NEOLED)?
            IO_XIRQ_EN    => false, -- implement external interrupts controller (XIRQ)?
            IO_GPTMR_EN   => false, -- implement general purpose timer (GPTMR)?
            IO_XIP_EN     => false, -- implement execute in place module (XIP)?
            IO_ONEWIRE_EN => false, -- implement 1-wire interface (ONEWIRE)?
            IO_DMA_EN     => false, -- implement direct memory access controller (DMA)?
            IO_SLINK_EN   => false, -- implement stream link interface (SLINK)?
            IO_CRC_EN     => false  -- implement cyclic redundancy check unit (CRC)?
        )
        PORT MAP(
            clk_i      => clk_i,                -- global clock line
            wb_slave_i => wb_slaves_mux_req(3), -- control and data from master to slave
            wb_slave_o => wb_slaves_mux_resp(3) -- status and data from slave to master
        );

    gen_ocd_jtag : IF IMPLEMENT_JTAG = TRUE GENERATE
        -- Intel Cyclone IV JTAG atom --
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

        -- NEORV32 combined Debug Transport Module and Debug Module --
        neorv32_debug_inst : ENTITY work.neorv32_debug
            GENERIC MAP(
                NUM_HARTS => NUM_HARTS,   -- number of implemented harts i.e. CPUs
                BASE_ADDR => base_io_dm_c -- base address of this debug module
            )
            PORT MAP(
                -- Global control --
                clk_i  => clk_i,  -- global clock, rising edge
                rstn_i => rstn_i, -- global reset, low-active, async
                -- jtag connection --
                jtag_trst_i => '1',
                jtag_tck_i  => con_jtag_tck,
                jtag_tdi_i  => con_jtag_tdi,
                jtag_tdo_o  => con_jtag_tdo,
                jtag_tms_i  => con_jtag_tms,
                -- debug core interface (DCI) --
                dci_ndmrstn_o   => con_dci_ndmrstn,   -- soc reset (all harts)
                dci_halt_req_o  => con_dci_halt_req,  -- request hart to halt (enter debug mode)
                dci_cpu_debug_i => con_dci_cpu_debug, -- cpu is in debug mode
                -- Wishbone slave interface --
                wb_slave_i => wb_slaves_mux_req(4), -- control and data from master to slave
                wb_slave_o => wb_slaves_mux_resp(4) -- status and data from slave to master
            );
    END GENERATE;

END ARCHITECTURE top_arch;
