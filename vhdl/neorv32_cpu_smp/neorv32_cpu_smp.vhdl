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
        wb_master_o : OUT wb_master_tx_arr_t(2 * NUM_HARTS - 1 DOWNTO 0); -- control and data from master to slave
        wb_master_i : IN wb_master_rx_arr_t(2 * NUM_HARTS - 1 DOWNTO 0);  -- status and data from slave to master

        -- Advanced memory control signals --
        fence_o  : OUT STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0); -- indicates an executed FENCE operation
        fencei_o : OUT STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0); -- indicates an executed FENCEI operation

        -- CPU interrupts --
        msw_irq_i   : IN STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0) := (OTHERS => 'L'); -- machine software interrupt
        mext_irq_i  : IN STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0) := (OTHERS => 'L'); -- machine external interrupt
        mtime_irq_i : IN STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0) := (OTHERS => 'L')  -- machine timer interrupt, available if IO_MTIME_EN = false
    );
END ENTITY neorv32_cpu_smp;

ARCHITECTURE no_target_specific OF neorv32_cpu_smp IS

    -- Gateway from the neorv32 specific CPU bus to Wishbone.
    COMPONENT neorv32_wb_gateway IS
        PORT (
            -- Global control --
            clk_i  : IN STD_ULOGIC; -- global clock, rising edge
            rstn_i : IN STD_ULOGIC; -- global reset, low-active, async

            -- host access --
            addr_i : IN STD_ULOGIC_VECTOR(31 DOWNTO 0);  -- address
            rden_i : IN STD_ULOGIC;                      -- read enable
            wren_i : IN STD_ULOGIC;                      -- write enable
            ben_i  : IN STD_ULOGIC_VECTOR(03 DOWNTO 0);  -- byte write enable
            data_i : IN STD_ULOGIC_VECTOR(31 DOWNTO 0);  -- data in
            data_o : OUT STD_ULOGIC_VECTOR(31 DOWNTO 0); -- data out
            ack_o  : OUT STD_ULOGIC;                     -- transfer acknowledge
            err_o  : OUT STD_ULOGIC;                     -- transfer error

            -- Wishbone master interface --
            wb_master_o : OUT wb_master_tx_sig_t; -- control and data from master to slave
            wb_master_i : IN wb_master_rx_sig_t   -- status and data from slave to master
        );
    END COMPONENT neorv32_wb_gateway;

    -- CPU boot configuration --
    CONSTANT cpu_boot_addr_c : STD_ULOGIC_VECTOR(31 DOWNTO 0) := cond_sel_stdulogicvector_f(INT_BOOTLOADER_EN, boot_rom_base_c, ispace_base_c);

    -- reset generator --
    SIGNAL rstn_int_sreg : STD_ULOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL rstn_int : STD_ULOGIC;

    -- CPU status --
    TYPE cpu_status_t IS RECORD
        debug : STD_ULOGIC; -- set when in debug mode
        sleep : STD_ULOGIC; -- set when in sleep mode
    END RECORD;
    TYPE cpu_status_arr_t IS ARRAY (NUM_HARTS - 1 DOWNTO 0) OF cpu_status_t;
    SIGNAL cpu_s : cpu_status_arr_t;

    -- bus interface --
    TYPE bus_interface_t IS RECORD
        addr : STD_ULOGIC_VECTOR(31 DOWNTO 0); -- bus access address
        rdata : STD_ULOGIC_VECTOR(31 DOWNTO 0); -- bus read data
        wdata : STD_ULOGIC_VECTOR(31 DOWNTO 0); -- bus write data
        ben : STD_ULOGIC_VECTOR(03 DOWNTO 0); -- byte enable
        we : STD_ULOGIC; -- write request
        re : STD_ULOGIC; -- read request
        ack : STD_ULOGIC; -- bus transfer acknowledge
        err : STD_ULOGIC; -- bus transfer error
        src : STD_ULOGIC; -- access source (1=instruction fetch, 0=data access)
        cached : STD_ULOGIC; -- cached transfer
        priv : STD_ULOGIC; -- set when in privileged machine mode
    END RECORD;
    TYPE bus_interface_arr_t IS ARRAY (NUM_HARTS - 1 DOWNTO 0) OF bus_interface_t;
    SIGNAL cpu_i, i_cache, cpu_d : bus_interface_arr_t;
    SIGNAL d_fence, i_fence : STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0);

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
        neorv32_cpu_inst : neorv32_cpu
        GENERIC MAP(
            -- General --
            HART_ID             => STD_ULOGIC_VECTOR(to_unsigned(i, 32)), -- hardware thread ID
            VENDOR_ID           => x"0000_0000",                          -- vendor's JEDEC ID
            CPU_BOOT_ADDR       => cpu_boot_addr_c,                       -- cpu boot address
            CPU_DEBUG_PARK_ADDR => dm_park_entry_c,                       -- cpu debug mode parking loop entry address
            CPU_DEBUG_EXC_ADDR  => dm_exc_entry_c,                        -- cpu debug mode exception entry address
            -- RISC-V CPU Extensions --
            CPU_EXTENSION_RISCV_B        => false, -- implement bit-manipulation extension?
            CPU_EXTENSION_RISCV_C        => false, -- implement compressed extension?
            CPU_EXTENSION_RISCV_E        => false, -- implement embedded RF extension?
            CPU_EXTENSION_RISCV_M        => true,  -- implement mul/div extension?
            CPU_EXTENSION_RISCV_U        => false, -- implement user mode extension?
            CPU_EXTENSION_RISCV_Zfinx    => false, -- implement 32-bit floating-point extension (using INT reg!)
            CPU_EXTENSION_RISCV_Zicntr   => true,  -- implement base counters?
            CPU_EXTENSION_RISCV_Zicond   => false, -- implement conditional operations extension?
            CPU_EXTENSION_RISCV_Zihpm    => false, -- implement hardware performance monitors?
            CPU_EXTENSION_RISCV_Zifencei => true,  -- implement instruction stream sync.?
            CPU_EXTENSION_RISCV_Zmmul    => false, -- implement multiply-only M sub-extension?
            CPU_EXTENSION_RISCV_Zxcfu    => false, -- implement custom (instr.) functions unit?
            CPU_EXTENSION_RISCV_Sdext    => false, -- implement external debug mode extension?
            CPU_EXTENSION_RISCV_Sdtrig   => false, -- implement debug mode trigger module extension?
            -- Extension Options --
            FAST_MUL_EN     => true, -- use DSPs for M extension's multiplier
            FAST_SHIFT_EN   => true, -- use barrel shifter for shift operations
            CPU_IPB_ENTRIES => 2,    -- entries is instruction prefetch buffer, has to be a power of 1
            -- Physical Memory Protection (PMP) --
            PMP_NUM_REGIONS     => 0, -- number of regions (0..16)
            PMP_MIN_GRANULARITY => 4, -- minimal region granularity in bytes, has to be a power of 2, min 4 bytes
            -- Hardware Performance Monitors (HPM) --
            HPM_NUM_CNTS  => 0, -- number of implemented HPM counters (0..29)
            HPM_CNT_WIDTH => 0  -- total size of HPM counters (0..64)
        )
        PORT MAP(
            -- global control --
            clk_i   => clk_i,          -- global clock, rising edge
            rstn_i  => rstn_int,       -- global reset, low-active, async
            sleep_o => cpu_s(i).sleep, -- cpu is in sleep mode when set
            debug_o => cpu_s(i).debug, -- cpu is in debug mode when set
            -- instruction bus interface --
            i_bus_addr_o  => cpu_i(i).addr,  -- bus access address
            i_bus_rdata_i => cpu_i(i).rdata, -- bus read data
            i_bus_re_o    => cpu_i(i).re,    -- read request
            i_bus_ack_i   => cpu_i(i).ack,   -- bus transfer acknowledge
            i_bus_err_i   => cpu_i(i).err,   -- bus transfer error
            i_bus_fence_o => i_fence(i),     -- executed FENCEI operation
            i_bus_priv_o  => cpu_i(i).priv,  -- current effective privilege level
            -- data bus interface --
            d_bus_addr_o  => cpu_d(i).addr,  -- bus access address
            d_bus_rdata_i => cpu_d(i).rdata, -- bus read data
            d_bus_wdata_o => cpu_d(i).wdata, -- bus write data
            d_bus_ben_o   => cpu_d(i).ben,   -- byte enable
            d_bus_we_o    => cpu_d(i).we,    -- write request
            d_bus_re_o    => cpu_d(i).re,    -- read request
            d_bus_ack_i   => cpu_d(i).ack,   -- bus transfer acknowledge
            d_bus_err_i   => cpu_d(i).err,   -- bus transfer error
            d_bus_fence_o => d_fence(i),     -- executed FENCE operation
            d_bus_priv_o  => cpu_d(i).priv,  -- current effective privilege level
            -- interrupts --
            msw_irq_i     => msw_irq_i(i),   -- risc-v: machine software interrupt
            mext_irq_i    => mext_irq_i(i),  -- risc-v: machine external interrupt
            mtime_irq_i   => mtime_irq_i(i), -- risc-v: machine timer interrupt
            firq_i => (OTHERS => '0'),       -- custom: fast interrupts
            db_halt_req_i => '0'             -- risc-v: halt request (debug mode)
        );

        -- initialized but unused --
        cpu_i(i).wdata <= (OTHERS => '0');
        cpu_i(i).ben <= (OTHERS => '0');
        cpu_i(i).we <= '0'; -- read-only
        cpu_i(i).src <= '1'; -- 1 = instruction fetch
        cpu_i(i).cached <= '0';
        cpu_d(i).src <= '0'; -- 0 = data access
        cpu_d(i).cached <= '0';

        -- advanced memory control --
        fence_o(i) <= d_fence(i); -- indicates an executed FENCE operation
        fencei_o(i) <= i_fence(i); -- indicates an executed FENCE.I operation

        -- convert cpu internal data bus to external Wishbone bus
        neorv32_wb_gateway_dbus : neorv32_wb_gateway
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,    -- global clock, rising edge
            rstn_i => rstn_int, -- global reset, low-active, async
            -- host access --
            addr_i => cpu_d(i).addr,  -- address
            rden_i => cpu_d(i).re,    -- read enable
            wren_i => cpu_d(i).we,    -- write enable
            ben_i  => cpu_d(i).ben,   -- byte write enable
            data_i => cpu_d(i).wdata, -- data in
            data_o => cpu_d(i).rdata, -- data out
            ack_o  => cpu_d(i).ack,   -- transfer acknowledge
            err_o  => cpu_d(i).err,   -- transfer error
            -- Wishbone master interface --
            wb_master_o => wb_master_o(2 * i), -- control and data from master to slave
            wb_master_i => wb_master_i(2 * i)  -- status and data from slave to master
        );
    END GENERATE;

    -- CPU Instruction Cache(s) ---------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    neorv32_icache_gen : FOR i IN 0 TO NUM_HARTS - 1 GENERATE
        neorv32_icache_true : IF ICACHE_EN = true GENERATE
            neorv32_icache_inst : neorv32_icache
            GENERIC MAP(
                ICACHE_NUM_BLOCKS => ICACHE_NUM_BLOCKS,   -- number of blocks (min 2), has to be a power of 2
                ICACHE_BLOCK_SIZE => ICACHE_BLOCK_SIZE,   -- block size in bytes (min 4), has to be a power of 2
                ICACHE_NUM_SETS   => ICACHE_ASSOCIATIVITY -- associativity / number of sets (1=direct_mapped), has to be a power of 2
            )
            PORT MAP(
                -- global control --
                clk_i   => clk_i,      -- global clock, rising edge
                rstn_i  => rstn_int,   -- global reset, low-active, async
                clear_i => i_fence(i), -- cache clear
                -- host controller interface --
                host_addr_i  => cpu_i(i).addr,  -- bus access address
                host_rdata_o => cpu_i(i).rdata, -- bus read data
                host_re_i    => cpu_i(i).re,    -- read enable
                host_ack_o   => cpu_i(i).ack,   -- bus transfer acknowledge
                host_err_o   => cpu_i(i).err,   -- bus transfer error
                -- peripheral bus interface --
                bus_cached_o => i_cache(i).cached, -- set if cached (!) access in progress
                bus_addr_o   => i_cache(i).addr,   -- bus access address
                bus_rdata_i  => i_cache(i).rdata,  -- bus read data
                bus_re_o     => i_cache(i).re,     -- read enable
                bus_ack_i    => i_cache(i).ack,    -- bus transfer acknowledge
                bus_err_i    => i_cache(i).err     -- bus transfer error
            );
        END GENERATE;

        neorv32_icache_ngen : IF ICACHE_EN = false GENERATE
            -- direct forward
            i_cache(i).cached <= '0';
            i_cache(i).addr <= cpu_i(i).addr;
            i_cache(i).re <= cpu_i(i).re;
            cpu_i(i).rdata <= i_cache(i).rdata;
            cpu_i(i).ack <= i_cache(i).ack;
            cpu_i(i).err <= i_cache(i).err;
        END GENERATE;

        i_cache(i).wdata <= (OTHERS => '0');
        i_cache(i).ben <= (OTHERS => '0');
        i_cache(i).we <= '0';
        i_cache(i).priv <= cpu_i(i).priv;
        i_cache(i).src <= '0'; -- not used

        -- convert cpu internal instruction bus to external Wishbone bus
        neorv32_wb_gateway_dbus : neorv32_wb_gateway
        PORT MAP(
            -- Global control --
            clk_i  => clk_i,    -- global clock, rising edge
            rstn_i => rstn_int, -- global reset, low-active, async
            -- host access --
            addr_i => i_cache(i).addr,  -- address
            rden_i => i_cache(i).re,    -- read enable
            wren_i => '0',              -- write enable
            ben_i => (OTHERS => '0'),   -- byte write enable
            data_i => (OTHERS => '0'),  -- data in
            data_o => i_cache(i).rdata, -- data out
            ack_o  => i_cache(i).ack,   -- transfer acknowledge
            err_o  => i_cache(i).err,   -- transfer error
            -- Wishbone master interface --
            wb_master_o => wb_master_o(2 * i + 1), -- control and data from master to slave
            wb_master_i => wb_master_i(2 * i + 1)  -- status and data from slave to master
        );
    END GENERATE;

END ARCHITECTURE no_target_specific;
