-- =============================================================================
-- File:                    top.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  top
--
-- Description:             Toplevel entity for SoC project based on NEORV32.
--
-- Changes:                 0.1, 2023-01-16, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

ENTITY top IS
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, async
        -- JTAG --
        altera_reserved_tck : IN STD_ULOGIC;
        altera_reserved_tms : IN STD_ULOGIC;
        altera_reserved_tdi : IN STD_ULOGIC;
        altera_reserved_tdo : OUT STD_ULOGIC;
        -- XIP (execute in place via SPI) --
        xip_csn_o   : OUT STD_ULOGIC;        -- chip-select, low-active
        xip_holdn_o : OUT STD_ULOGIC := '1'; -- hold serial communication, low-active
        xip_clk_o   : OUT STD_ULOGIC;        -- serial clock
        xip_sdi_i   : IN STD_ULOGIC := 'L';  -- device data input
        xip_sdo_o   : OUT STD_ULOGIC;        -- controller data output
        xip_wpn_o   : OUT STD_ULOGIC := '1'; -- write-protect, low-active
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
        sdram_clk   : OUT STD_LOGIC;                                          -- clk
        -- DEBUG over PMOD --
        dbg : OUT STD_ULOGIC_VECTOR(6 DOWNTO 0)
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

    COMPONENT wb_sdram IS
        GENERIC (
            -- General --
            CLOCK_FREQUENCY : NATURAL; -- clock frequency of clk_i in Hz
            BASE_ADDRESS    : UNSIGNED -- start address of SDRAM
        );
        PORT (
            -- Global control --
            clk_i  : IN STD_ULOGIC; -- global clock, rising edge
            rstn_i : IN STD_ULOGIC; -- global reset, low-active, asyn
            -- Wishbone slave interface --
            wb_tag_i : IN STD_ULOGIC_VECTOR(02 DOWNTO 0);  -- request tag
            wb_adr_i : IN STD_ULOGIC_VECTOR(31 DOWNTO 0);  -- address
            wb_dat_i : IN STD_ULOGIC_VECTOR(31 DOWNTO 0);  -- read data
            wb_dat_o : OUT STD_ULOGIC_VECTOR(31 DOWNTO 0); -- write data
            wb_we_i  : IN STD_ULOGIC;                      -- read/write
            wb_sel_i : IN STD_ULOGIC_VECTOR(03 DOWNTO 0);  -- byte enable
            wb_stb_i : IN STD_ULOGIC;                      -- strobe
            wb_cyc_i : IN STD_ULOGIC;                      -- valid cycle
            wb_ack_o : OUT STD_ULOGIC;                     -- transfer acknowledge
            wb_err_o : OUT STD_ULOGIC;                     -- transfer error
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
    END COMPONENT wb_sdram;

    CONSTANT CLOCK_FREQUENCY : POSITIVE := 50000000; -- clock frequency of clk_i in Hz

    SIGNAL con_jtag_tck, con_jtag_tdi, con_jtag_tdo, con_jtag_tms : STD_LOGIC;

    SIGNAL con_wb_tag : STD_ULOGIC_VECTOR(02 DOWNTO 0); -- request tag
    SIGNAL con_wb_adr : STD_ULOGIC_VECTOR(31 DOWNTO 0); -- address
    SIGNAL con_wb_dat_i : STD_ULOGIC_VECTOR(31 DOWNTO 0); -- read data
    SIGNAL con_wb_dat_o : STD_ULOGIC_VECTOR(31 DOWNTO 0); -- write data
    SIGNAL con_wb_we : STD_ULOGIC; -- read/write
    SIGNAL con_wb_sel : STD_ULOGIC_VECTOR(03 DOWNTO 0); -- byte enable
    SIGNAL con_wb_stb : STD_ULOGIC; -- strobe
    SIGNAL con_wb_cyc : STD_ULOGIC; -- valid cycle
    SIGNAL con_wb_ack : STD_ULOGIC; -- transfer acknowledge
    SIGNAL con_wb_err : STD_ULOGIC := '0'; -- transfer error

    SIGNAL con_gpio_o : STD_ULOGIC_VECTOR(63 DOWNTO 0);
BEGIN
    -- The Core Of The Problem ----------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    neorv32_top_inst : neorv32_top
    GENERIC MAP(
        -- General --
        CLOCK_FREQUENCY   => CLOCK_FREQUENCY, -- clock frequency of clk_i in Hz
        INT_BOOTLOADER_EN => true,            -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM
        -- On-Chip Debugger (OCD) --
        ON_CHIP_DEBUGGER_EN => true, -- implement on-chip debugger
        -- RISC-V CPU Extensions --
        CPU_EXTENSION_RISCV_B        => true, -- implement bit-manipulation extension?
        CPU_EXTENSION_RISCV_C        => true, -- implement compressed extension?
        CPU_EXTENSION_RISCV_M        => true, -- implement mul/div extension?
        CPU_EXTENSION_RISCV_Zicsr    => true, -- implement CSR system?
        CPU_EXTENSION_RISCV_Zicntr   => true, -- implement base counters?
        CPU_EXTENSION_RISCV_Zifencei => true, -- implement instruction stream sync.? (required for the on-chip debugger)
        -- Tuning Options --
        FAST_MUL_EN   => true, -- use DSPs for M extension's multiplier
        FAST_SHIFT_EN => true, -- use barrel shifter for shift operations
        -- Internal Instruction memory --
        MEM_INT_IMEM_EN   => true,      -- implement processor-internal instruction memory
        MEM_INT_IMEM_SIZE => 32 * 1024, -- size of processor-internal instruction memory in bytes
        -- Internal Data memory --
        MEM_INT_DMEM_EN   => true,     -- implement processor-internal data memory
        MEM_INT_DMEM_SIZE => 8 * 1024, -- size of processor-internal data memory in bytes
        -- External memory interface --
        MEM_EXT_EN => true, -- implement external memory bus interface?
        -- average delay of SDRAM is about 4096 cycles, double it to be safe
        MEM_EXT_TIMEOUT  => 8191,  -- cycles after a pending bus access auto-terminates (0 = disabled)
        MEM_EXT_ASYNC_RX => false, -- use register buffer for RX data when false
        MEM_EXT_ASYNC_TX => false, -- use register buffer for TX data when false
        -- Processor peripherals --
        IO_GPIO_NUM      => 64,   -- number of GPIO input/output pairs (0..64)
        IO_MTIME_EN      => true, -- implement machine system timer (MTIME)?
        IO_UART0_EN      => true, -- implement primary universal asynchronous receiver/transmitter (UART0)?
        IO_UART0_RX_FIFO => 32,   -- RX fifo depth, has to be a power of two, min 1
        IO_UART0_TX_FIFO => 32,   -- TX fifo depth, has to be a power of two, min 1
        IO_TRNG_EN       => true, -- implement true random number generator (TRNG)?
        IO_XIP_EN        => false -- implement execute in place module (XIP)?
    )
    PORT MAP(
        -- Global control --
        clk_i  => clk_i,  -- global clock, rising edge
        rstn_i => rstn_i, -- global reset, low-active, async
        -- JTAG on-chip debugger interface (available if ON_CHIP_DEBUGGER_EN = true) --
        jtag_trst_i => '1',          -- low-active TAP reset (optional)
        jtag_tck_i  => con_jtag_tck, -- serial clock
        jtag_tdi_i  => con_jtag_tdi, -- serial data input
        jtag_tdo_o  => con_jtag_tdo, -- serial data output
        jtag_tms_i  => con_jtag_tms, -- mode select
        -- Wishbone bus interface (available if MEM_EXT_EN = true) --
        wb_tag_o => con_wb_tag,   -- request tag
        wb_adr_o => con_wb_adr,   -- address
        wb_dat_i => con_wb_dat_i, -- read data
        wb_dat_o => con_wb_dat_o, -- write data
        wb_we_o  => con_wb_we,    -- read/write
        wb_sel_o => con_wb_sel,   -- byte enable
        wb_stb_o => con_wb_stb,   -- strobe
        wb_cyc_o => con_wb_cyc,   -- valid cycle
        wb_ack_i => con_wb_ack,   -- transfer acknowledge
        wb_err_i => con_wb_err,   -- transfer error
        -- XIP (execute in place via SPI) signals (available if IO_XIP_EN = true) --
        xip_csn_o => xip_csn_o, -- chip-select, low-active
        xip_clk_o => xip_clk_o, -- serial clock
        xip_sdi_i => xip_sdi_i, -- device data input
        xip_sdo_o => xip_sdo_o, -- controller data output
        -- GPIO (available if IO_GPIO_EN = true) --
        gpio_o => con_gpio_o, -- parallel output
        -- primary UART0 (available if IO_UART0_EN = true) --
        uart0_txd_o => uart0_txd_o, -- UART0 send data
        uart0_rxd_i => uart0_rxd_i  -- UART0 receive data
    );

    -- GPIO output --
    gpio0_o <= con_gpio_o(7 DOWNTO 0);

    -- JTAG atom --
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

    -- SDRAM Controller --
    wb_sdram_inst : wb_sdram
    GENERIC MAP(
        -- General --
        CLOCK_FREQUENCY => CLOCK_FREQUENCY, -- clock frequency of clk_i in Hz
        BASE_ADDRESS    => x"4000_0000"     -- start address of SDRAM
    )
    PORT MAP(
        -- Global control --
        clk_i  => clk_i,  -- global clock, rising edge
        rstn_i => rstn_i, -- global reset, low-active, asyn
        -- Wishbone slave interface --
        wb_tag_i => con_wb_tag,   -- request tag
        wb_adr_i => con_wb_adr,   -- address
        wb_dat_i => con_wb_dat_o, -- read data
        wb_dat_o => con_wb_dat_i, -- write data
        wb_we_i  => con_wb_we,    -- read/write
        wb_sel_i => con_wb_sel,   -- byte enable
        wb_stb_i => con_wb_stb,   -- strobe
        wb_cyc_i => con_wb_cyc,   -- valid cycle
        wb_ack_o => con_wb_ack,   -- transfer acknowledge
        wb_err_o => con_wb_err,   -- transfer error
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

    -- DEBUG --
    gpio1_o <= STD_ULOGIC_VECTOR(con_wb_adr(7 DOWNTO 0));
    gpio2_o <= STD_ULOGIC_VECTOR(con_wb_adr(15 DOWNTO 8));
    gpio3_o <= STD_ULOGIC_VECTOR(con_wb_adr(23 DOWNTO 16));
    gpio4_o <= STD_ULOGIC_VECTOR(con_wb_adr(31 DOWNTO 24));

    -- Wishbone DEBUG --
    dbg(0) <= con_wb_we; -- read/write
    dbg(1) <= con_wb_stb; -- strobe
    dbg(2) <= con_wb_cyc; -- valid cycle
    dbg(3) <= con_wb_ack; -- transfer acknowledge

END ARCHITECTURE top_arch;
