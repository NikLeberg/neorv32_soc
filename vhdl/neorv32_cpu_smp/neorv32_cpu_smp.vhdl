-- =============================================================================
-- File:                    neorv32_cpu_smp.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.4
--
-- Entity:                  neorv32_cpu_smp
--
-- Description:             Custom version of neorv32_cpu of neorv32 system. It
--                          removes a lot of the nice configurability of the
--                          default implementation but instead provides multi
--                          core CPU support.
--
-- Note 1:                  Large chunks of this file are a 1:1 copy from
--                          neorv32_top.vhd Copyright (c) 2024, Stephan Nolting.
--                          See respective file for more information.
--
-- Note 2:                  This is a work in progress! Many things need to be
--                          fixed or implemented before this can be a even
--                          remotely efficient and usable SMP system:
--                          - [x] allow harts to reset eachother
--                          - [ ] add L2 cache with coherency
--                          - [-] implement mailbox system for IPC?
--                          - [x] implement efficient crossbar switch
--                          - [x] adapt default IMEM to be dual-port
--                          - [ ] add software support i.e. FreeRTOS
--                                > see https://github.com/raspberrypi/pico-sdk
--                          - [x] where is (shall be) the stack of the smp cpus?
--                          - [x] A extension support
--                                > emulation over traps with lr sc possible
--
-- Changes:                 0.1, 2023-04-16, leuen4
--                              initial version
--                          0.2, 2023-04-23, leuen4
--                              combine d and i Wishbone bus into single array
--                          0.3, 2023-08-28, leuen4
--                              add signals for on-chip debuggers core interface
--                          0.4, 2024-08-05, leuen4
--                              merge i- and d-bus with bus switch, separate
--                              cpus into primary and secondary
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

USE work.wbp_pkg.ALL;

ENTITY neorv32_cpu_smp IS
    GENERIC (
        -- General --
        NUM_HARTS               : NATURAL RANGE 1 TO 32 := 2;     -- number of implemented harts i.e. CPUs
        PRIMARY_CPU_BOOT_ADDR   : STD_ULOGIC_VECTOR(31 DOWNTO 0); -- boot address of primary CPU (hartid = 0)
        SECONDARY_CPU_BOOT_ADDR : STD_ULOGIC_VECTOR(31 DOWNTO 0); -- boot address of secondary CPU(s) (hartid != 0)

        -- Internal Instruction Cache (iCACHE, per HART) --
        ICACHE_EN         : BOOLEAN                    := true; -- implement instruction cache
        ICACHE_NUM_BLOCKS : NATURAL RANGE 1 TO 256     := 4;    -- i-cache: number of blocks (min 1), has to be a power of 2
        ICACHE_BLOCK_SIZE : NATURAL RANGE 4 TO 2 ** 16 := 64;   -- i-cache: block size in bytes (min 4), has to be a power of 2

        -- On-Chip Debugger (OCD) --
        ON_CHIP_DEBUGGER_EN : BOOLEAN := false -- implement on-chip debugger
    );
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, synchronous

        -- Wishbone bus interfaces --
        wbp_mosi : OUT wbp_mosi_arr_t(NUM_HARTS - 1 DOWNTO 0); -- control and data from master to slave
        wbp_miso : IN wbp_miso_arr_t(NUM_HARTS - 1 DOWNTO 0);  -- status and data from slave to master

        -- CPU interrupts --
        mtime_irq_i : IN STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0) := (OTHERS => 'L'); -- machine timer interrupt
        msw_irq_i   : IN STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0) := (OTHERS => 'L'); -- machine software interrupt
        mext_irq_i  : IN STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0) := (OTHERS => 'L'); -- machine external interrupt

        -- debug core interface (DCI) --
        dci_ndmrstn_i   : IN STD_ULOGIC;                                -- soc reset (all harts)
        dci_halt_req_i  : IN STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0); -- request hart to halt (enter debug mode)
        dci_cpu_debug_o : OUT STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0) -- cpu is in debug mode when set
    );
END ENTITY neorv32_cpu_smp;

ARCHITECTURE no_target_specific OF neorv32_cpu_smp IS

    -- reset generator --
    SIGNAL rstn_cpu : STD_ULOGIC;

    -- bus: core complex --
    TYPE bus_reqs_t IS ARRAY (NATURAL RANGE <>) OF bus_req_t;
    TYPE bus_rsps_t IS ARRAY (NATURAL RANGE <>) OF bus_rsp_t;
    SIGNAL cpu_i_req, cpu_d_req, icache_req, core_req : bus_reqs_t(NUM_HARTS - 1 DOWNTO 0);
    SIGNAL cpu_i_rsp, cpu_d_rsp, icache_rsp, core_rsp : bus_rsps_t(NUM_HARTS - 1 DOWNTO 0);

BEGIN

    -- Reset Generator ------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    rstn_cpu <= rstn_i AND dci_ndmrstn_i;

    -- CPU Core(s) ----------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    neorv32_cpu_gen : FOR i IN 0 TO NUM_HARTS - 1 GENERATE
        neorv32_cpu_primary_gen : IF i = 0 GENERATE
            neorv32_cpu_inst : ENTITY neorv32.neorv32_cpu
                GENERIC MAP(
                    -- General --
                    HART_ID => (OTHERS => '0'),
                    VENDOR_ID => (OTHERS => '0'),
                    CPU_BOOT_ADDR       => PRIMARY_CPU_BOOT_ADDR,
                    CPU_DEBUG_PARK_ADDR => dm_park_entry_c,
                    CPU_DEBUG_EXC_ADDR  => dm_exc_entry_c,
                    -- RISC-V CPU Extensions --
                    CPU_EXTENSION_RISCV_A      => true,
                    CPU_EXTENSION_RISCV_B      => false,
                    CPU_EXTENSION_RISCV_C      => false,
                    CPU_EXTENSION_RISCV_E      => false,
                    CPU_EXTENSION_RISCV_M      => false,
                    CPU_EXTENSION_RISCV_U      => false,
                    CPU_EXTENSION_RISCV_Zbkb   => false,
                    CPU_EXTENSION_RISCV_Zbkc   => false,
                    CPU_EXTENSION_RISCV_Zbkx   => false,
                    CPU_EXTENSION_RISCV_Zfinx  => false,
                    CPU_EXTENSION_RISCV_Zicntr => true,
                    CPU_EXTENSION_RISCV_Zicond => false,
                    CPU_EXTENSION_RISCV_Zihpm  => false,
                    CPU_EXTENSION_RISCV_Zknd   => false,
                    CPU_EXTENSION_RISCV_Zkne   => false,
                    CPU_EXTENSION_RISCV_Zknh   => false,
                    CPU_EXTENSION_RISCV_Zksed  => false,
                    CPU_EXTENSION_RISCV_Zksh   => false,
                    CPU_EXTENSION_RISCV_Zmmul  => false,
                    CPU_EXTENSION_RISCV_Zxcfu  => false,
                    CPU_EXTENSION_RISCV_Sdext  => ON_CHIP_DEBUGGER_EN,
                    CPU_EXTENSION_RISCV_Sdtrig => ON_CHIP_DEBUGGER_EN,
                    CPU_EXTENSION_RISCV_Smpmp  => false,
                    -- Tuning Options --
                    FAST_MUL_EN    => false,
                    FAST_SHIFT_EN  => false,
                    REGFILE_HW_RST => false,
                    -- Physical Memory Protection (PMP) --
                    PMP_NUM_REGIONS     => 0,
                    PMP_MIN_GRANULARITY => 4,
                    PMP_TOR_MODE_EN     => true,
                    PMP_NAP_MODE_EN     => true,
                    -- Hardware Performance Monitors (HPM) --
                    HPM_NUM_CNTS  => 0,
                    HPM_CNT_WIDTH => 40
                )
                PORT MAP(
                    -- global control --
                    clk_i     => clk_i, -- switchable clock
                    clk_aux_i => clk_i,
                    rstn_i    => rstn_cpu,
                    sleep_o   => OPEN,
                    debug_o   => dci_cpu_debug_o(0),
                    -- interrupts --
                    msi_i => msw_irq_i(0),
                    mei_i => mext_irq_i(0),
                    mti_i => mtime_irq_i(0),
                    firq_i => (OTHERS => '0'),
                    dbi_i => dci_halt_req_i(0),
                    -- instruction bus interface --
                    ibus_req_o => cpu_i_req(0),
                    ibus_rsp_i => cpu_i_rsp(0),
                    -- data bus interface --
                    dbus_req_o => cpu_d_req(0),
                    dbus_rsp_i => cpu_d_rsp(0)
                );

        END GENERATE; -- /neorv32_cpu_primary_gen

        neorv32_cpu_secondary_gen : IF i /= 0 GENERATE
            neorv32_cpu_inst : ENTITY neorv32.neorv32_cpu
                GENERIC MAP(
                    -- General --
                    HART_ID             => STD_ULOGIC_VECTOR(to_unsigned(i, 32)),
                    VENDOR_ID => (OTHERS => '0'),
                    CPU_BOOT_ADDR       => SECONDARY_CPU_BOOT_ADDR,
                    CPU_DEBUG_PARK_ADDR => dm_park_entry_c,
                    CPU_DEBUG_EXC_ADDR  => dm_exc_entry_c,
                    -- RISC-V CPU Extensions --
                    CPU_EXTENSION_RISCV_A      => true,
                    CPU_EXTENSION_RISCV_B      => false,
                    CPU_EXTENSION_RISCV_C      => false,
                    CPU_EXTENSION_RISCV_E      => false,
                    CPU_EXTENSION_RISCV_M      => false,
                    CPU_EXTENSION_RISCV_U      => false,
                    CPU_EXTENSION_RISCV_Zbkb   => false,
                    CPU_EXTENSION_RISCV_Zbkc   => false,
                    CPU_EXTENSION_RISCV_Zbkx   => false,
                    CPU_EXTENSION_RISCV_Zfinx  => false,
                    CPU_EXTENSION_RISCV_Zicntr => false,
                    CPU_EXTENSION_RISCV_Zicond => false,
                    CPU_EXTENSION_RISCV_Zihpm  => false,
                    CPU_EXTENSION_RISCV_Zknd   => false,
                    CPU_EXTENSION_RISCV_Zkne   => false,
                    CPU_EXTENSION_RISCV_Zknh   => false,
                    CPU_EXTENSION_RISCV_Zksed  => false,
                    CPU_EXTENSION_RISCV_Zksh   => false,
                    CPU_EXTENSION_RISCV_Zmmul  => false,
                    CPU_EXTENSION_RISCV_Zxcfu  => false,
                    CPU_EXTENSION_RISCV_Sdext  => ON_CHIP_DEBUGGER_EN,
                    CPU_EXTENSION_RISCV_Sdtrig => ON_CHIP_DEBUGGER_EN,
                    CPU_EXTENSION_RISCV_Smpmp  => false,
                    -- Tuning Options --
                    FAST_MUL_EN    => false,
                    FAST_SHIFT_EN  => false,
                    REGFILE_HW_RST => false,
                    -- Physical Memory Protection (PMP) --
                    PMP_NUM_REGIONS     => 0,
                    PMP_MIN_GRANULARITY => 4,
                    PMP_TOR_MODE_EN     => true,
                    PMP_NAP_MODE_EN     => true,
                    -- Hardware Performance Monitors (HPM) --
                    HPM_NUM_CNTS  => 0,
                    HPM_CNT_WIDTH => 40
                )
                PORT MAP(
                    -- global control --
                    clk_i     => clk_i, -- switchable clock
                    clk_aux_i => clk_i,
                    rstn_i    => rstn_cpu,
                    sleep_o   => OPEN,
                    debug_o   => dci_cpu_debug_o(i),
                    -- interrupts --
                    msi_i => msw_irq_i(i),
                    mei_i => mext_irq_i(i),
                    mti_i => mtime_irq_i(i),
                    firq_i => (OTHERS => '0'),
                    dbi_i => dci_halt_req_i(i),
                    -- instruction bus interface --
                    ibus_req_o => cpu_i_req(i),
                    ibus_rsp_i => cpu_i_rsp(i),
                    -- data bus interface --
                    dbus_req_o => cpu_d_req(i),
                    dbus_rsp_i => cpu_d_rsp(i)
                );

        END GENERATE; -- /neorv32_cpu_secondary_gen

        -- CPU Instruction Cache (I-Cache) --------------------------------------------------------
        -- -------------------------------------------------------------------------------------------
        neorv32_icache_gen : IF ICACHE_EN GENERATE
            neorv32_icache_inst : ENTITY neorv32.neorv32_cache
                GENERIC MAP(
                    NUM_BLOCKS => ICACHE_NUM_BLOCKS,
                    BLOCK_SIZE => ICACHE_BLOCK_SIZE,
                    UC_BEGIN   => uncached_begin_c(31 DOWNTO 28),
                    UC_ENABLE  => true,
                    READ_ONLY  => true
                )
                PORT MAP(
                    clk_i      => clk_i,
                    rstn_i     => rstn_i,
                    host_req_i => cpu_i_req(i),
                    host_rsp_o => cpu_i_rsp(i),
                    bus_req_o  => icache_req(i),
                    bus_rsp_i  => icache_rsp(i)
                );
        END GENERATE; --/neorv32_icache_gen
        neorv32_icache_gen_false : IF NOT ICACHE_EN GENERATE
            icache_req(i) <= cpu_i_req(i);
            cpu_i_rsp(i) <= icache_rsp(i);
        END GENERATE; --/neorv32_icache_gen_false

        -- Core Complex Bus Switch ----------------------------------------------------------------
        -- -------------------------------------------------------------------------------------------
        neorv32_bus_switch_inst : ENTITY neorv32.neorv32_bus_switch
            GENERIC MAP(
                PORT_A_READ_ONLY => false,
                PORT_B_READ_ONLY => true -- i-fetch is read-only
            )
            PORT MAP(
                clk_i    => clk_i,
                rstn_i   => rstn_i,
                a_lock_i => '0',          -- no exclusive accesses for port A
                a_req_i  => cpu_d_req(i), -- prioritized
                a_rsp_o  => cpu_d_rsp(i),
                b_req_i  => icache_req(i),
                b_rsp_o  => icache_rsp(i),
                x_req_o  => core_req(i),
                x_rsp_i  => core_rsp(i)
            );

        -- External Bus Interface (XBUS) ----------------------------------------------------------
        -- -------------------------------------------------------------------------------------------
        neorv32_wbp_gateway_inst : ENTITY work.neorv32_wbp_gateway
            PORT MAP(
                clk_i    => clk_i,
                rstn_i   => rstn_i,
                req_i    => core_req(i),
                rsp_o    => core_rsp(i),
                wbp_mosi => wbp_mosi(i),
                wbp_miso => wbp_miso(i)
            );

    END GENERATE; -- /neorv32_cpu_gen

END ARCHITECTURE no_target_specific;
