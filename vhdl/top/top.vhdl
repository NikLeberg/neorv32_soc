-- =============================================================================
-- File:                    top.vhdl
--
-- Entity:                  top
--
-- Description:             Toplevel entity for SoC project based on NEORV32.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.7
--
-- Changes:                 0.1, 2023-01-16, NikLeberg
--                              initial version
--                          0.2, 2023-02-25, NikLeberg
--                              implement IMEM with SDRAM
--                          0.3, 2023-02-28, NikLeberg
--                              disable SDRAM and JTAG if simulating
--                          0.4, 2023-04-16, NikLeberg
--                              replace simple bus mux with crossbar
--                          0.5, 2023-04-23, NikLeberg
--                              remove GCD parts and build SMP system
--                          0.6, 2023-09-30, NikLeberg
--                              rework of interconnect: round-robin priority
--                          0.7, 2024-10-06, NikLeberg
--                              rework of interconnect: update to pipelined
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;
USE neorv32.neorv32_application_image.ALL; -- this file is generated by the image generator

USE work.wbp_pkg.ALL;

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
    SIGNAL con_dci_ndmrstn : STD_ULOGIC := '1';
    SIGNAL con_dci_halt_req : STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL con_dci_cpu_debug : STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0);

    -- Wishbone interface signals
    -- The frequently accessed slaves go through the high speed crossbar which
    -- enables simultaneous connections. The less frequently ones are connected
    -- through a single and simple low speed mux.
    CONSTANT WBP_N_MASTERS : NATURAL := NUM_HARTS;
    CONSTANT WBP_N_SLAVES_CROSSBAR : NATURAL := 4;
    CONSTANT WBP_N_SLAVES_MUX : NATURAL := 5;
    CONSTANT WBP_MEMORY_MAP_CROSSBAR : wbp_map_t :=
    (
    (x"0000_0000", 16 * 1024), -- IMEM, 16 KB (port a)
    (x"1000_0000", 16 * 1024), -- IMEM, 16 KB (port b)
    (x"8000_0000", 32 * 1024 * 1024), -- SDRAM, 32 MB
    (x"f000_0000", 256 * 1024 * 1024) -- IO, 256 MB
    );
    CONSTANT WBP_MEMORY_MAP_MUX : wbp_map_t :=
    (
    (x"f000_0000", 48 * 1024), -- CLINT, 48 KB (largely unused)
    (base_io_gpio_c, iodev_size_c), -- NEORV32 GPIO, 256 B
    (base_io_uart0_c, iodev_size_c), -- NEORV32 UART0, 256 B
    (base_io_sysinfo_c, iodev_size_c), -- NEORV32 SYSINFO, 256 B
    (base_io_dm_c, iodev_size_c) -- NEORV32 OCD, 256 B
    );
    -- remap accesses to IMEM port of some slaves to port b
    CONSTANT WBP_MEMORY_REMAP_FROM : wbp_map_t := (0 => (x"0000_0000", 1 * 1024)); -- IMEM, 1 KB (port a)
    CONSTANT WBP_MEMORY_REMAP_TO : wbp_map_t := (0 => (x"1000_0000", 1 * 1024)); -- IMEM, 1 KB (port b)
    SIGNAL wbp_masters_mosi : wbp_mosi_arr_t(WBP_N_MASTERS - 1 DOWNTO 0);
    SIGNAL wbp_masters_remapped_mosi : wbp_mosi_arr_t(WBP_N_MASTERS - 1 DOWNTO 0);
    SIGNAL wbp_masters_miso : wbp_miso_arr_t(WBP_N_MASTERS - 1 DOWNTO 0);
    SIGNAL wbp_slaves_cross_mosi : wbp_mosi_arr_t(WBP_N_SLAVES_CROSSBAR - 1 DOWNTO 0);
    SIGNAL wbp_slaves_cross_miso : wbp_miso_arr_t(WBP_N_SLAVES_CROSSBAR - 1 DOWNTO 0);
    SIGNAL wbp_slaves_mux_mosi : wbp_mosi_arr_t(WBP_N_SLAVES_MUX - 1 DOWNTO 0);
    SIGNAL wbp_slaves_mux_miso : wbp_miso_arr_t(WBP_N_SLAVES_MUX - 1 DOWNTO 0);
    -- Always idle master for unused dual-master entities. 
    CONSTANT wbp_master_no_req : wbp_mosi_sig_t := (cyc => '0', stb => '0', we => '0', sel => (OTHERS => '0'), adr => (OTHERS => '0'), dat => (OTHERS => '0'));

    SIGNAL wbp_dmem_portb_resp : wbp_miso_sig_t; -- dummy

    -- Change behaviour when simulating:
    --  > do not implement external sdram and replace with internal dmem
    --  > do not implement altera specific jtag atom
    CONSTANT IMPLEMENT_SDRAM : BOOLEAN := NOT SIMULATION;
    CONSTANT IMPLEMENT_DMEM : BOOLEAN := SIMULATION;
    CONSTANT IMPLEMENT_JTAG : BOOLEAN := NOT SIMULATION;

BEGIN

    -- The Core Of The Problem ----------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    neorv32_cpu_smp_inst : ENTITY work.neorv32_cpu_smp
        GENERIC MAP(
            -- General --
            NUM_HARTS               => NUM_HARTS,
            PRIMARY_CPU_BOOT_ADDR   => mem_imem_base_c,
            SECONDARY_CPU_BOOT_ADDR => mem_imem_base_c,
            -- Internal Instruction Cache (iCACHE, per HART) --
            ICACHE_EN         => true,
            ICACHE_NUM_BLOCKS => 4,
            ICACHE_BLOCK_SIZE => 64,
            -- On-Chip Debugger (OCD) --
            ON_CHIP_DEBUGGER_EN => IMPLEMENT_JTAG
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,
            rstn_i => rstn_i,
            -- Wishbone bus interface --
            wbp_mosi => wbp_masters_mosi,
            wbp_miso => wbp_masters_miso,
            -- CPU interrupts --
            mtime_irq_i => con_mti,
            msw_irq_i   => con_msi,
            mext_irq_i => (OTHERS => '0'),
            -- debug core interface (DCI) --
            dci_ndmrstn_i   => con_dci_ndmrstn,
            dci_halt_req_i  => con_dci_halt_req,
            dci_cpu_debug_o => con_dci_cpu_debug
        );

    -- Wishbone Interconnect (Remapper + Crossbar + Mux) --------------------------------------
    -- -------------------------------------------------------------------------------------------
    gen_remap : FOR i IN 0 TO NUM_HARTS - 1 GENERATE
        -- every second hart gets remapped address space
        gen_hart_even : IF i MOD 2 = 0 GENERATE
            wbp_remap_inst : ENTITY work.wbp_remap
                GENERIC MAP(
                    MEMORY_MAP_FROM => WBP_MEMORY_REMAP_FROM, -- from what address
                    MEMORY_MAP_TO   => WBP_MEMORY_REMAP_TO    -- to what address
                )
                PORT MAP(
                    -- Wishbone master interface --
                    wbp_orig_mosi  => wbp_masters_mosi(i),         -- original request
                    wbp_remap_mosi => wbp_masters_remapped_mosi(i) -- remapped request
                );
        END GENERATE gen_hart_even;

        -- other harts keep the original address spaceaddresses
        gen_hart_odd : IF i MOD 2 = 1 GENERATE
            wbp_masters_remapped_mosi(i) <= wbp_masters_mosi(i);
        END GENERATE gen_hart_odd;
    END GENERATE gen_remap;

    wbp_xbar_inst : ENTITY work.wbp_xbar
        GENERIC MAP(
            -- General --
            N_MASTERS  => WBP_N_MASTERS,
            N_SLAVES   => WBP_N_SLAVES_CROSSBAR,
            MEMORY_MAP => WBP_MEMORY_MAP_CROSSBAR
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,
            rstn_i => rstn_i,
            -- Wishbone master interface(s) --
            wbp_masters_mosi => wbp_masters_remapped_mosi,
            wbp_masters_miso => wbp_masters_miso,
            -- Wishbone slave interface(s) --
            wbp_slaves_mosi => wbp_slaves_cross_mosi,
            wbp_slaves_miso => wbp_slaves_cross_miso
        );

    wbp_mux_inst : ENTITY work.wbp_mux
        GENERIC MAP(
            -- General --
            N_SLAVES   => WBP_N_SLAVES_MUX,
            MEMORY_MAP => WBP_MEMORY_MAP_MUX
        )
        PORT MAP(
            -- Wishbone master interface --
            wbp_master_mosi => wbp_slaves_cross_mosi(3),
            wbp_master_miso => wbp_slaves_cross_miso(3),
            -- Wishbone slave interface(s) --
            wbp_slaves_mosi => wbp_slaves_mux_mosi,
            wbp_slaves_miso => wbp_slaves_mux_miso
        );

    -- Memory subsystems (IMEM + DMEM) --------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    -- IMEM dual-port RAM --
    gen_imem_syn : IF SIMULATION = FALSE GENERATE
        wbp_imem_inst : ENTITY work.wbp_mem(synthesis)
            GENERIC MAP(
                MEM_SIZE  => 16 * 1024,
                MEM_IMAGE => application_init_image
            )
            PORT MAP(
                -- Global control --
                clk_i  => clk_i,
                rstn_i => rstn_i,
                -- Wishbone slave interfaces --
                wbp_mosi => wbp_slaves_cross_mosi(1 DOWNTO 0),
                wbp_miso => wbp_slaves_cross_miso(1 DOWNTO 0)
            );
    END GENERATE;
    gen_imem_sim : IF SIMULATION = TRUE GENERATE
        wbp_imem_inst : ENTITY work.wbp_mem(simulation)
            GENERIC MAP(
                MEM_SIZE  => 16 * 1024,
                MEM_IMAGE => application_init_image
            )
            PORT MAP(
                -- Global control --
                clk_i  => clk_i,
                rstn_i => rstn_i,
                -- Wishbone slave interfaces --
                wbp_mosi => wbp_slaves_cross_mosi(1 DOWNTO 0),
                wbp_miso => wbp_slaves_cross_miso(1 DOWNTO 0)
            );
    END GENERATE;

    -- SDRAM Controller --
    gen_sdram : IF IMPLEMENT_SDRAM = TRUE GENERATE
        ASSERT false REPORT "WBP wrapper of SDRAM not implemented yet." SEVERITY error;
        -- TODO: Implement wbp wrapper for physical SDRAM.
        -- wb_sdram_inst : ENTITY work.wb_sdram
        --     GENERIC MAP(
        --         -- General --
        --         CLOCK_FREQUENCY => CLOCK_FREQUENCY
        --     )
        --     PORT MAP(
        --         -- Global control --
        --         clk_i  => clk_i,
        --         rstn_i => rstn_i,
        --         -- Wishbone slave interface --
        --         wb_slave_i => wbp_slaves_cross_mosi(2),
        --         wb_slave_o => wbp_slaves_cross_miso(2),
        --         -- SDRAM --
        --         sdram_addr  => sdram_addr,
        --         sdram_ba    => sdram_ba,
        --         sdram_n_cas => sdram_n_cas,
        --         sdram_cke   => sdram_cke,
        --         sdram_n_cs  => sdram_n_cs,
        --         sdram_d     => sdram_d,
        --         sdram_dqm   => sdram_dqm,
        --         sdram_n_ras => sdram_n_ras,
        --         sdram_n_we  => sdram_n_we,
        --         sdram_clk   => sdram_clk
        --     );
    END GENERATE;

    -- DRAM --
    gen_dmem : IF IMPLEMENT_DMEM = TRUE GENERATE
        gen_dmem_syn : IF SIMULATION = FALSE GENERATE
            wbp_dmem_inst : ENTITY work.wbp_mem(synthesis)
                GENERIC MAP(
                    MEM_SIZE => 32 * 1024
                )
                PORT MAP(
                    -- Global control --
                    clk_i  => clk_i,
                    rstn_i => rstn_i,
                    -- Wishbone slave interfaces --
                    wbp_mosi(0) => wbp_slaves_cross_mosi(2),
                    wbp_mosi(1) => wbp_master_no_req,
                    wbp_miso(0) => wbp_slaves_cross_miso(2),
                    wbp_miso(1) => wbp_dmem_portb_resp
                );
        END GENERATE;
        gen_dmem_sim : IF SIMULATION = TRUE GENERATE
            wbp_dmem_inst : ENTITY work.wbp_mem(simulation)
                GENERIC MAP(
                    MEM_SIZE => 32 * 1024
                )
                PORT MAP(
                    -- Global control --
                    clk_i  => clk_i,
                    rstn_i => rstn_i,
                    -- Wishbone slave interfaces --
                    wbp_mosi(0) => wbp_slaves_cross_mosi(2),
                    wbp_mosi(1) => wbp_master_no_req,
                    wbp_miso(0) => wbp_slaves_cross_miso(2),
                    wbp_miso(1) => wbp_dmem_portb_resp
                );
        END GENERATE;
    END GENERATE;

    -- Core Local Interruptor (CLINT) --
    wbp_riscv_clint_inst : ENTITY work.wbp_riscv_clint
        GENERIC MAP(
            N_HARTS => NUM_HARTS
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,
            rstn_i => rstn_i,
            -- Wishbone slave interface --
            wbp_mosi => wbp_slaves_mux_mosi(0),
            wbp_miso => wbp_slaves_mux_miso(0),
            -- IRQs --
            mtime_irq_o => con_mti,
            msw_irq_o   => con_msi
        );

    -- NEORV32 IO Modules ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    neorv32_wbp_gpio_inst : ENTITY work.neorv32_wbp_gpio
        GENERIC MAP(
            GPIO_NUM => 8
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,
            rstn_i => rstn_i,
            -- Wishbone slave interface --
            wbp_mosi => wbp_slaves_mux_mosi(1),
            wbp_miso => wbp_slaves_mux_miso(1),
            -- parallel io --
            gpio_o => con_gpio_o,
            gpio_i => (OTHERS => '0')
        );

    -- GPIO output --
    gpio0_o <= con_gpio_o(7 DOWNTO 0);

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
                NUM_HARTS => NUM_HARTS,
                BASE_ADDR => base_io_dm_c
            )
            PORT MAP(
                -- Global control --
                clk_i  => clk_i,
                rstn_i => rstn_i,
                -- jtag connection --
                jtag_tck_i => con_jtag_tck,
                jtag_tdi_i => con_jtag_tdi,
                jtag_tdo_o => con_jtag_tdo,
                jtag_tms_i => con_jtag_tms,
                -- debug core interface (DCI) --
                dci_ndmrstn_o   => con_dci_ndmrstn,
                dci_halt_req_o  => con_dci_halt_req,
                dci_cpu_debug_i => con_dci_cpu_debug,
                -- Wishbone slave interface --
                wbp_mosi => wbp_slaves_mux_mosi(4),
                wbp_miso => wbp_slaves_mux_miso(4)
            );
    END GENERATE;

END ARCHITECTURE top_arch;
