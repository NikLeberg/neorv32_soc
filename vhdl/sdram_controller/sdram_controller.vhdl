-- =============================================================================
-- File:                    sdram_controller.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  sdram_controller
--
-- Description:             Wishbone wrapper for SDRAM controller of nullobject
--                          https://github.com/nullobject/sdram-fpga. Configured
--                          to work with the ISSI IS42VM16160K located on the
--                          Gecko4Education board. Datasheet:
--                          https://gecko-wiki.ti.bfh.ch/_media/gecko4education:is42vm16160k.pdf
--
-- Note:                    The Wishbone bus is organized with 32 bit addresses
--                          and byte resolution. The SDRAM has 256 Mbit of data
--                          with an address resolution of 24 bits that each
--                          address 16 bits of data. The SDRAM controller from
--                          nullobject abstracts this away to 32 bit data access
--                          by issuing a burst read/write of two addresses. This
--                          leaves 23 bits of address with a data resolution of
--                          32 bits.
--                          The 32 bit Wishbone address is split up like so:
--                           - first 7 bits: coarse SDRAM address
--                           - next 23 bits: fine SDRAM address
--                           - last  2 bits: allways zero because byte access is
--                                           not allowed, only 32 bit word.
--
-- Changes:                 0.1, 2023-02-05, leuen4
--                              initial version
--                          0.2, 2023-02-19, leuen4
--                              fix byte/word access
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

ENTITY sdram_controller IS
    GENERIC (
        -- General --
        CLOCK_FREQUENCY : NATURAL               := 50000000;    -- clock frequency of clk_i in Hz
        BASE_ADDRESS    : UNSIGNED(31 DOWNTO 0) := x"0000_0000" -- start address of SDRAM
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
END ENTITY sdram_controller;

ARCHITECTURE no_target_specific OF sdram_controller IS
    COMPONENT sdram IS
        GENERIC (
            -- clock frequency (in MHz)
            -- This value must be provided, as it is used to calculate the number of
            -- clock cycles required for the other timing values.
            CLK_FREQ : real;
            -- 32-bit controller interface
            ADDR_WIDTH : NATURAL := 23; -- 23 bit address with 32 bit data = 32 MB
            DATA_WIDTH : NATURAL := 32;
            -- SDRAM interface
            SDRAM_ADDR_WIDTH : NATURAL := 13;
            SDRAM_DATA_WIDTH : NATURAL := 16;
            SDRAM_COL_WIDTH  : NATURAL := 9;
            SDRAM_ROW_WIDTH  : NATURAL := 13;
            SDRAM_BANK_WIDTH : NATURAL := 2;
            -- The delay in clock cycles, between the start of a read command and the
            -- availability of the output data.
            CAS_LATENCY : NATURAL := 2; -- 2=below 133MHz, 3=above 133MHz
            -- The number of 16-bit words to be bursted during a read/write.
            BURST_LENGTH : NATURAL := 2;
            -- timing values (in nanoseconds)
            -- These values can be adjusted to match the exact timing of your SDRAM
            -- chip (refer to the datasheet).
            T_DESL : real := 200000.0; -- startup delay
            T_MRD  : real := 12.0;     -- mode register cycle time
            T_RC   : real := 60.0;     -- row cycle time
            T_RCD  : real := 18.0;     -- RAS to CAS delay
            T_RP   : real := 18.0;     -- precharge to activate delay
            T_WR   : real := 12.0;     -- write recovery time
            T_REFI : real := 7800.0    -- average refresh interval
        );
        PORT (
            -- reset
            reset : IN STD_LOGIC := '0';
            -- clock
            clk : IN STD_LOGIC;
            -- address bus
            addr : IN unsigned(ADDR_WIDTH - 1 DOWNTO 0);
            -- input data bus
            data : IN STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
            -- When the write enable signal is asserted, a write operation will be performed.
            we : IN STD_LOGIC;
            -- When the request signal is asserted, an operation will be performed.
            req : IN STD_LOGIC;
            -- The acknowledge signal is asserted by the SDRAM controller when
            -- a request has been accepted.
            ack : OUT STD_LOGIC;
            -- The valid signal is asserted when there is a valid word on the output
            -- data bus.
            valid : OUT STD_LOGIC;
            -- output data bus
            q : OUT STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
            -- SDRAM interface (e.g. AS4C16M16SA-6TCN, IS42S16400F, etc.)
            sdram_a     : OUT unsigned(SDRAM_ADDR_WIDTH - 1 DOWNTO 0);
            sdram_ba    : OUT unsigned(SDRAM_BANK_WIDTH - 1 DOWNTO 0);
            sdram_dq    : INOUT STD_LOGIC_VECTOR(SDRAM_DATA_WIDTH - 1 DOWNTO 0);
            sdram_cke   : OUT STD_LOGIC;
            sdram_cs_n  : OUT STD_LOGIC;
            sdram_ras_n : OUT STD_LOGIC;
            sdram_cas_n : OUT STD_LOGIC;
            sdram_we_n  : OUT STD_LOGIC;
            sdram_dqml  : OUT STD_LOGIC;
            sdram_dqmh  : OUT STD_LOGIC
        );
    END COMPONENT sdram;

    -- Helper signals --
    SIGNAL rst : STD_ULOGIC;
    SIGNAL wb_tag_i_res : STD_LOGIC_VECTOR(02 DOWNTO 0); -- request tag
    SIGNAL wb_adr_i_u : UNSIGNED(31 DOWNTO 0); -- address
    SIGNAL wb_dat_i_res : STD_LOGIC_VECTOR(31 DOWNTO 0); -- read data
    SIGNAL wb_dat_o_res : STD_LOGIC_VECTOR(31 DOWNTO 0); -- write data
    SIGNAL wb_sel_i_res : STD_LOGIC_VECTOR(03 DOWNTO 0); -- byte enable

    -- Selected signal --
    SIGNAL selected : STD_LOGIC;

    -- Handshake signals --
    SIGNAL sdram_req, sdram_ack, sdram_valid : STD_LOGIC;
BEGIN
    -- Convert Wishbone signals to the resolved or casted signals --
    wb_tag_i_res <= STD_LOGIC_VECTOR(wb_tag_i);
    wb_adr_i_u <= UNSIGNED(wb_adr_i);
    wb_dat_i_res <= STD_LOGIC_VECTOR(wb_dat_i);
    wb_dat_o <= STD_ULOGIC_VECTOR(wb_dat_o_res);
    wb_sel_i_res <= STD_LOGIC_VECTOR(wb_sel_i_res);

    -- Coarse decode Wishbone address (7 MSB bits) and generate select signal --
    selected <= '1' WHEN wb_adr_i_u(31 DOWNTO 25) = BASE_ADDRESS(31 DOWNTO 25) ELSE
        '0';

    -- Generate handshake signals --
    -- SDRAM is requested to read/write data when the address matches, a
    -- wishbone cycle is ongoing and the current wb signals are valid (strobe).
    sdram_req <= selected AND wb_cyc_i AND wb_stb_i;
    -- Wishbone transaction is acknowledged when:
    --  - read operation:  sdram has valid data (valid signal asserted)
    --  - write operation: sdram did ack transaction (ack signal asserted)
    wb_ack_o <= '0' WHEN sdram_req = '0' ELSE
        '1' WHEN wb_we_i = '0' AND sdram_valid = '1' ELSE -- read
        '1' WHEN wb_we_i = '1' AND sdram_ack = '1' ELSE -- write
        '0';
    -- Wishbone transaction goes into error when address is unaligned.
    wb_err_o <= '1' WHEN wb_adr_i(1 DOWNTO 0) /= "00" AND selected = '1' ELSE
        '0';

    -- Negate reset signal --
    rst <= NOT rstn_i;

    -- SDRAM Controller --
    sdram_inst : sdram
    GENERIC MAP(
        -- clock frequency (in MHz)
        CLK_FREQ => (real(CLOCK_FREQUENCY) / 1000000.0),
        -- timing values (in nanoseconds)
        T_DESL => 100000.0, -- startup delay
        T_MRD  => 40.0,     -- mode register cycle time
        T_RC   => 60.0,     -- row cycle time
        T_RCD  => 22.5,     -- RAS to CAS delay
        T_RP   => 22.5,     -- precharge to activate delay
        T_WR   => 22.5,     -- write recovery time
        T_REFI => 7800.0    -- average refresh interval
    )
    PORT MAP(
        reset => rst,
        clk   => clk_i,
        -- Interconnect --
        addr  => wb_adr_i_u(24 DOWNTO 2), -- address bus (convert byte address to word address)
        data  => wb_dat_i_res,            -- input data bus
        we    => wb_we_i,                 -- asserted == write operation
        req   => sdram_req,               -- asserted == operation will be performed
        ack   => sdram_ack,               -- asserted == request accepted
        valid => sdram_valid,             -- asserted == data from sdram valid
        q     => wb_dat_o_res,            -- output data bus
        -- SDRAM interface --
        sdram_a     => sdram_addr,
        sdram_ba    => sdram_ba,
        sdram_dq    => sdram_d,
        sdram_cke   => sdram_cke,
        sdram_cs_n  => sdram_n_cs,
        sdram_ras_n => sdram_n_ras,
        sdram_cas_n => sdram_n_cas,
        sdram_we_n  => sdram_n_we,
        sdram_dqml  => sdram_dqm(0),
        sdram_dqmh  => sdram_dqm(1)
    );

    -- SDRAM clk output --
    sdram_clk <= clk_i;

END ARCHITECTURE no_target_specific;
