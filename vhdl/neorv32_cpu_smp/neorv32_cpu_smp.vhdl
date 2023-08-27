-- =============================================================================
-- File:                    neorv32_cpu_smp.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  neorv32_cpu_smp
--
-- Description:             Custom version of neorv32_top of neorv32 system. It
--                          removes a lot of the nice configurability of the
--                          default implementation but instead provides multi
--                          core CPU support.
--
-- Note 1:                  Large chunks of this file are a 1:1 copy from
--                          neorv32_top.vhd Copyright (c) 2023, Stephan Nolting.
--                          See respective file for more information.
--
-- Note 2:                  This is a work in progress! Many things need to be
--                          fixed or implemented before this can be a even
--                          remotely efficient and usable SMP system:
--                          - [ ] allow harts to reset eachother
--                          - [ ] add L2 cache with coherency
--                          - [ ] implement mailbox system for IPC?
--                          - [x] implement efficient crossbar switch
--                          - [x] adapt default IMEM to be dual-port
--                          - [ ] add software support i.e. FreeRTOS
--                                > see https://github.com/raspberrypi/pico-sdk
--                          - [ ] where is (shall be) the stack of the smp cpus?
--                          - [ ] A extension support
--                                > emulation over traps with lr sc possible
--
-- Changes:                 0.1, 2023-04-16, leuen4
--                              initial version
--                          0.2, 2023-04-23, leuen4
--                              combine d and i Wishbone bus into single array
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

USE work.wb_pkg.ALL;

ENTITY neorv32_cpu_smp IS
    GENERIC (
        -- General --
        CLOCK_FREQUENCY   : NATURAL;          -- clock frequency of clk_i in Hz
        NUM_HARTS         : NATURAL;          -- number of implemented harts i.e. CPUs
        INT_BOOTLOADER_EN : BOOLEAN := false; -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM

        -- Internal Instruction Cache (iCACHE) --
        ICACHE_EN            : BOOLEAN := false; -- implement instruction cache
        ICACHE_NUM_BLOCKS    : NATURAL := 4;     -- i-cache: number of blocks (min 1), has to be a power of 2
        ICACHE_BLOCK_SIZE    : NATURAL := 64;    -- i-cache: block size in bytes (min 4), has to be a power of 2
        ICACHE_ASSOCIATIVITY : NATURAL := 1      -- i-cache: associativity / number of sets (1=direct_mapped), has to be a power of 2
    );
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, async

        -- Wishbone bus interfaces, two per hart --
        -- for two harts the ordering is 0: d_bus(0), 1: i_bus(0), 2: d_bus(1), 3: i_bus(1)
        wb_master_o : OUT wb_req_arr_t(2 * NUM_HARTS - 1 DOWNTO 0); -- control and data from master to slave
        wb_master_i : IN wb_resp_arr_t(2 * NUM_HARTS - 1 DOWNTO 0); -- status and data from slave to master

        -- Advanced memory control signals --
        fence_o  : OUT STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0); -- indicates an executed FENCE operation
        fencei_o : OUT STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0); -- indicates an executed FENCEI operation

        -- CPU interrupts --
        mti_i : IN STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0) := (OTHERS => 'L'); -- risc-v machine timer interrupt
        msi_i : IN STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0) := (OTHERS => 'L'); -- risc-v machine software interrupt
        mei_i : IN STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0) := (OTHERS => 'L')  -- risc-v machine external interrupt
    );
END ENTITY neorv32_cpu_smp;

ARCHITECTURE no_target_specific OF neorv32_cpu_smp IS

    -- CPU boot configuration --
    CONSTANT cpu_boot_addr_c : STD_ULOGIC_VECTOR(31 DOWNTO 0) := cond_sel_suv_f(INT_BOOTLOADER_EN, mem_boot_base_c, mem_imem_base_c);

    -- reset generator --
    SIGNAL rstn_int_sreg : STD_ULOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL rstn_int : STD_ULOGIC;

    -- CPU status --
    TYPE cpu_status_t IS RECORD
        cpu_debug : STD_ULOGIC; -- cpu is in debug mode
        cpu_sleep : STD_ULOGIC; -- cpu is in sleep mode
        i_fence : STD_ULOGIC; -- instruction fence
        d_fence : STD_ULOGIC; -- data fence
    END RECORD;
    TYPE cpu_status_arr_t IS ARRAY (NUM_HARTS - 1 DOWNTO 0) OF cpu_status_t;
    SIGNAL cpu_s : cpu_status_arr_t;

    -- bus interface --
    TYPE bus_req_arr_t IS ARRAY (NUM_HARTS - 1 DOWNTO 0) OF bus_req_t;
    TYPE bus_rsp_arr_t IS ARRAY (NUM_HARTS - 1 DOWNTO 0) OF bus_rsp_t;
    SIGNAL i_cpu_req, i_cache_req, d_cpu_req : bus_req_arr_t;
    SIGNAL i_cpu_rsp, i_cache_rsp, d_cpu_rsp : bus_rsp_arr_t;

    -- Wishbone bus gateway FSM --
    TYPE wb_bus_state_t IS RECORD
        cyc : STD_ULOGIC; -- cycle in progress
        we : STD_ULOGIC; -- read = '0' / write = '1'
        ack : STD_ULOGIC;
    END RECORD;
    TYPE wb_bus_state_arr_t IS ARRAY (NUM_HARTS - 1 DOWNTO 0) OF wb_bus_state_t;
    SIGNAL wb_bus_i, wb_bus_d : wb_bus_state_arr_t;

BEGIN

    -- ****************************************************************************************************************************
    -- Clock and Reset System
    -- ****************************************************************************************************************************

    -- Reset Generator ------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    reset_generator : PROCESS (rstn_i, clk_i)
    BEGIN
        IF (rstn_i = '0') THEN
            rstn_int_sreg <= (OTHERS => '0');
            rstn_int <= '0';
        ELSIF falling_edge(clk_i) THEN -- inverted clock to release reset _before_ all FFs trigger (rising edge)
            -- internal reset --
            rstn_int_sreg <= rstn_int_sreg(rstn_int_sreg'left - 1 DOWNTO 0) & '1'; -- active for at least <rstn_int_sreg'size> clock cycles
            -- reset nets --
            rstn_int <= and_reduce_f(rstn_int_sreg); -- internal reset (via reset pin, WDT or OCD)
        END IF;
    END PROCESS reset_generator;

    -- ****************************************************************************************************************************
    -- CPU Core Complex
    -- ****************************************************************************************************************************

    -- CPU Core(s) ----------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    neorv32_cpu_gen : FOR i IN 0 TO NUM_HARTS - 1 GENERATE
        neorv32_cpu_inst : ENTITY neorv32.neorv32_cpu
            GENERIC MAP(
                -- General --
                HART_ID             => STD_ULOGIC_VECTOR(to_unsigned(i, 32)), -- hardware thread ID
                VENDOR_ID           => x"0000_0000",                          -- vendor's JEDEC ID
                CPU_BOOT_ADDR       => cpu_boot_addr_c,                       -- cpu boot address
                CPU_DEBUG_PARK_ADDR => dm_park_entry_c,                       -- cpu debug mode parking loop entry address
                CPU_DEBUG_EXC_ADDR  => dm_exc_entry_c,                        -- cpu debug mode exception entry address
                -- RISC-V CPU Extensions --
                CPU_EXTENSION_RISCV_A        => true,  -- implement atomic memory operations extension?
                CPU_EXTENSION_RISCV_B        => false, -- implement bit-manipulation extension?
                CPU_EXTENSION_RISCV_C        => false, -- implement compressed extension?
                CPU_EXTENSION_RISCV_E        => false, -- implement embedded RF extension?
                CPU_EXTENSION_RISCV_M        => true,  -- implement mul/div extension?
                CPU_EXTENSION_RISCV_U        => false, -- implement user mode extension?
                CPU_EXTENSION_RISCV_Zfinx    => false, -- implement 32-bit floating-point extension (using INT reg!)
                CPU_EXTENSION_RISCV_Zicntr   => true,  -- implement base counters?
                CPU_EXTENSION_RISCV_Zihpm    => false, -- implement hardware performance monitors?
                CPU_EXTENSION_RISCV_Zifencei => true,  -- implement instruction stream sync.?
                CPU_EXTENSION_RISCV_Zmmul    => false, -- implement multiply-only M sub-extension?
                CPU_EXTENSION_RISCV_Zxcfu    => false, -- implement custom (instr.) functions unit?
                CPU_EXTENSION_RISCV_Sdext    => false, -- implement external debug mode extension?
                CPU_EXTENSION_RISCV_Sdtrig   => false, -- implement debug mode trigger module extension?
                -- Extension Options --
                FAST_MUL_EN   => true, -- use DSPs for M extension's multiplier
                FAST_SHIFT_EN => true, -- use barrel shifter for shift operations
                -- Physical Memory Protection (PMP) --
                PMP_NUM_REGIONS     => 0, -- number of regions (0..16)
                PMP_MIN_GRANULARITY => 4, -- minimal region granularity in bytes, has to be a power of 2, min 4 bytes
                -- Hardware Performance Monitors (HPM) --
                HPM_NUM_CNTS  => 0, -- number of implemented HPM counters (0..29)
                HPM_CNT_WIDTH => 0  -- total size of HPM counters (0..64)
            )
            PORT MAP(
                -- global control --
                clk_i    => clk_i,              -- global clock, rising edge
                rstn_i   => rstn_int,           -- global reset, low-active, async
                sleep_o  => cpu_s(i).cpu_sleep, -- cpu is in sleep mode when set
                debug_o  => cpu_s(i).cpu_debug, -- cpu is in debug mode when set
                ifence_o => cpu_s(i).i_fence,   -- instruction fence
                dfence_o => cpu_s(i).d_fence,   -- data fence
                -- instruction bus interface --
                ibus_req_o => i_cpu_req(i), -- request bus
                ibus_rsp_i => i_cpu_rsp(i), -- response bus
                -- data bus interface --
                dbus_req_o => d_cpu_req(i), -- request bus
                dbus_rsp_i => d_cpu_rsp(i), -- response bus
                -- interrupts --
                msi_i => msi_i(i),         -- risc-v: machine software interrupt
                mei_i => mei_i(i),         -- risc-v: machine external interrupt
                mti_i => mti_i(i),         -- risc-v: machine timer interrupt
                firq_i => (OTHERS => '0'), -- custom: fast interrupts
                dbi_i => '0'               -- risc-v debug halt request interrupt
            );

        -- advanced memory control --
        fence_o(i) <= cpu_s(i).d_fence; -- indicates an executed FENCE operation
        fencei_o(i) <= cpu_s(i).i_fence; -- indicates an executed FENCE.I operation

        -- convert cpu internal data bus to external Wishbone bus
        neorv32_wb_gateway_dbus : ENTITY work.neorv32_wb_gateway
            PORT MAP(
                -- Global control --
                clk_i  => clk_i,    -- global clock, rising edge
                rstn_i => rstn_int, -- global reset, low-active, async
                -- host access --
                req_i => d_cpu_req(i), -- request bus
                rsp_o => d_cpu_rsp(i), -- response bus
                -- Wishbone master interface --
                wb_master_o => wb_master_o(2 * i), -- control and data from master to slave
                wb_master_i => wb_master_i(2 * i)  -- status and data from slave to master
            );
    END GENERATE;

    -- CPU Instruction Cache(s) ---------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    neorv32_icache_gen : FOR i IN 0 TO NUM_HARTS - 1 GENERATE
        neorv32_icache_true : IF ICACHE_EN = true GENERATE
            neorv32_icache_inst : ENTITY neorv32.neorv32_icache
                GENERIC MAP(
                    ICACHE_NUM_BLOCKS => ICACHE_NUM_BLOCKS,             -- number of blocks (min 2), has to be a power of 2
                    ICACHE_BLOCK_SIZE => ICACHE_BLOCK_SIZE,             -- block size in bytes (min 4), has to be a power of 2
                    ICACHE_NUM_SETS   => ICACHE_ASSOCIATIVITY,          -- associativity / number of sets (1=direct_mapped), has to be a power of 2
                    ICACHE_UC_PBEGIN  => uncached_begin_c(31 DOWNTO 28) -- begin of uncached address space (page number)
                )
                PORT MAP(
                    -- global control --
                    clk_i   => clk_i,            -- global clock, rising edge
                    rstn_i  => rstn_int,         -- global reset, low-active, async
                    clear_i => cpu_s(i).i_fence, -- cache clear
                    -- host controller interface --
                    cpu_req_i => i_cpu_req(i),
                    cpu_rsp_o => i_cpu_rsp(i),
                    -- peripheral bus interface --
                    bus_req_o => i_cache_req(i),
                    bus_rsp_i => i_cache_rsp(i)
                );
        END GENERATE;

        neorv32_icache_ngen : IF ICACHE_EN = false GENERATE
            -- direct forward
            i_cache_req(i) <= i_cpu_req(i);
            i_cpu_rsp(i) <= i_cache_rsp(i);
        END GENERATE;

        -- convert cpu internal instruction bus to external Wishbone bus
        neorv32_wb_gateway_inst : ENTITY work.neorv32_wb_gateway
            PORT MAP(
                -- Global control --
                clk_i  => clk_i,    -- global clock, rising edge
                rstn_i => rstn_int, -- global reset, low-active, async
                -- host access --
                req_i => i_cache_req(i), -- request bus
                rsp_o => i_cache_rsp(i), -- response bus
                -- Wishbone master interface --
                wb_master_o => wb_master_o(2 * i + 1), -- control and data from master to slave
                wb_master_i => wb_master_i(2 * i + 1)  -- status and data from slave to master
            );
    END GENERATE;

END ARCHITECTURE no_target_specific;
