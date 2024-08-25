-- =============================================================================
-- File:                    wb_sdram.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.5
--
-- Entity:                  wb_sdram
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
--                           - last  2 bits: ignored by address bus but used for
--                                           byte enable mask to read/write
--                                           individual bytes 
--                          Supports: - 32 bit r/w on 4 byte boundaries
--                                    - 16 bit r/w on 2 byte boundaries
--                                    -  8 bit r/w on any byte address
--
-- Changes:                 0.1, 2023-02-05, leuen4
--                              initial version
--                          0.2, 2023-02-19, leuen4
--                              fix byte/word access
--                          0.3, 2023-02-22, leuen4
--                              rename entity from sdram_controller to ws_sdram
--                          0.4, 2023-02-25, leuen4
--                              allow for individual byte access with masking
--                          0.5, 2023-02-26, leuen4
--                              remove coarse address decoding to make Wishbone
--                              interconnect compatible
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_sdram IS
    GENERIC (
        -- General --
        CLOCK_FREQUENCY : NATURAL := 50000000 -- clock frequency of clk_i in Hz
    );
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, syn
        -- Wishbone slave interface --
        wb_slave_i : IN wb_req_sig_t;
        wb_slave_o : OUT wb_resp_sig_t;
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
END ENTITY wb_sdram;

ARCHITECTURE no_target_specific OF wb_sdram IS
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
            reset : IN STD_ULOGIC := '0';
            -- clock
            clk : IN STD_ULOGIC;
            -- address bus
            addr : IN UNSIGNED(ADDR_WIDTH - 1 DOWNTO 0);
            -- byte enable
            benable : IN STD_ULOGIC_VECTOR(DATA_WIDTH/8 - 1 DOWNTO 0);
            -- input data bus
            data : IN STD_ULOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
            -- When the write enable signal is asserted, a write operation will be performed.
            we : IN STD_ULOGIC;
            -- When the request signal is asserted, an operation will be performed.
            req : IN STD_ULOGIC;
            -- The acknowledge signal is asserted by the SDRAM controller when
            -- a request has been accepted.
            ack : OUT STD_ULOGIC;
            -- The valid signal is asserted when there is a valid word on the output
            -- data bus.
            valid : OUT STD_ULOGIC;
            -- output data bus
            q : OUT STD_ULOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
            -- SDRAM interface (e.g. AS4C16M16SA-6TCN, IS42S16400F, etc.)
            sdram_a     : OUT UNSIGNED(SDRAM_ADDR_WIDTH - 1 DOWNTO 0);
            sdram_ba    : OUT UNSIGNED(SDRAM_BANK_WIDTH - 1 DOWNTO 0);
            sdram_dq    : INOUT STD_ULOGIC_VECTOR(SDRAM_DATA_WIDTH - 1 DOWNTO 0);
            sdram_cke   : OUT STD_ULOGIC;
            sdram_cs_n  : OUT STD_ULOGIC;
            sdram_ras_n : OUT STD_ULOGIC;
            sdram_cas_n : OUT STD_ULOGIC;
            sdram_we_n  : OUT STD_ULOGIC;
            sdram_dqml  : OUT STD_ULOGIC;
            sdram_dqmh  : OUT STD_ULOGIC
        );
    END COMPONENT sdram;

    -- Wishbone signals --
    SIGNAL wb_adr_i_u : UNSIGNED(31 DOWNTO 0); -- address

    -- SDRAM signals --
    SIGNAL sdram_rst : STD_ULOGIC; -- reset, non inverted
    SIGNAL sdram_req, sdram_ack, sdram_valid : STD_ULOGIC; -- handshake

    -- Access Request FSM --
    TYPE req_state_t IS (IDLE, WAIT_ACK, WAIT_VALID, DONE);
    SIGNAL req_state, req_state_next : req_state_t := IDLE;
BEGIN
    -- Convert Wishbone address to resolved unsigned signal --
    wb_adr_i_u <= UNSIGNED(wb_slave_i.adr);

    -- Access Request FSM --
    --  > The sdram_req signal shall only be active until ack is asserted by the
    --    controller. Otherwise a consecutive read/write is triggered.
    --  > The Wishbone request is acknowledged after an sdram_valid for reads or
    --  > after an sdram_ack for writes.
    --  > Address and data bus are not registered, SDRAM controller handles it.
    request_fsm_ff : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF rstn_i = '0' THEN
                req_state <= IDLE;
            ELSE
                req_state <= req_state_next;
            END IF;
        END IF;
    END PROCESS request_fsm_ff;

    request_fsm_nsl : PROCESS (req_state, wb_slave_i, sdram_ack, sdram_valid) IS
    BEGIN
        req_state_next <= req_state; -- default assignment
        CASE req_state IS
            WHEN IDLE =>
                IF wb_slave_i.stb = '1' THEN
                    req_state_next <= WAIT_ACK;
                END IF;
            WHEN WAIT_ACK => -- wait for ack signal
                IF sdram_ack = '1' AND wb_slave_i.we = '0' THEN
                    req_state_next <= WAIT_VALID;
                ELSIF sdram_ack = '1' AND wb_slave_i.we = '1' THEN
                    req_state_next <= DONE;
                END IF;
            WHEN WAIT_VALID => -- wait for valid signal (for reads)
                IF sdram_valid = '1' THEN
                    req_state_next <= DONE;
                END IF;
            WHEN DONE => -- done with request, send wishbone ack
                req_state_next <= IDLE;
            WHEN OTHERS =>
                req_state_next <= IDLE;
        END CASE;

        -- Always abort request if Wishbone cycle terminates.
        IF wb_slave_i.stb = '0' THEN
            req_state_next <= IDLE;
        END IF;
    END PROCESS request_fsm_nsl;

    -- SDRAM extra signals --
    sdram_rst <= NOT rstn_i;
    sdram_clk <= clk_i;
    sdram_req <= '1' WHEN req_state = WAIT_ACK ELSE
        '0';
    wb_slave_o.ack <= '1' WHEN req_state = DONE ELSE
    '0';
    wb_slave_o.err <= '0';

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
        reset => sdram_rst,
        clk   => clk_i,
        -- Interconnect --
        addr    => wb_adr_i_u(24 DOWNTO 2), -- address bus (convert byte address to word address)
        benable => wb_slave_i.sel,          -- byte enable
        data    => wb_slave_i.dat,          -- input data bus
        we      => wb_slave_i.we,           -- asserted == write operation
        req     => sdram_req,               -- asserted == operation will be performed
        ack     => sdram_ack,               -- asserted == request accepted
        valid   => sdram_valid,             -- asserted == data from sdram valid
        q       => wb_slave_o.dat,          -- output data bus
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

END ARCHITECTURE no_target_specific;
