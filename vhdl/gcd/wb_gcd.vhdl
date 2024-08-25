-- =============================================================================
-- File:                    wb_gcd.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  wb_gcd
--
-- Description:             Wishbone wrapper for greatest common divisor as
--                          memory mapped hardware accelerator.
--
-- Note:                    To calculate a GCD value the Wishbone register have
--                          to be accessed in a fixed order:
--                           1. write dataa to word 0 (offset 0)
--                               > also clears result of previous calculation
--                           2. write dataa to word 1 (offset 4)
--                               > also triggers the actual calculation
--                           3. read result from word 2 (offset 8)
--                               > if read as all ones, then calculation is
--                                 ongoing, any other value will be the result
--
-- Changes:                 0.1, 2023-02-27, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_gcd IS
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, syn
        -- Wishbone slave interface --
        wb_slave_i : IN wb_req_sig_t;
        wb_slave_o : OUT wb_resp_sig_t
    );
END ENTITY wb_gcd;

ARCHITECTURE no_target_specific OF wb_gcd IS

    -- GCD Accelerator --
    COMPONENT gcd IS
        GENERIC (
            NBITS : POSITIVE := 32 -- width of data
        );
        PORT (
            clk    : IN STD_LOGIC := '0'; -- clock of the algorithm
            clk_en : IN STD_LOGIC := '0'; -- clock enable of the algorithm
            start  : IN STD_LOGIC := '0'; -- strobe to start the algorithm
            reset  : IN STD_LOGIC := '0'; -- reset of the algorithm

            dataa : IN UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0'); -- first input number
            datab : IN UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0'); -- second input number

            done  : OUT STD_LOGIC := '0'; -- strobe to signal that the algorithm is done
            ready : OUT STD_LOGIC := '1'; -- signal that the block is ready for a new calculation

            result : OUT UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0') -- calculated result
        );
    END COMPONENT gcd;

    -- helper signals
    SIGNAL gcd_reset, gcd_start, gcd_done, gcd_ready : STD_ULOGIC;
    SIGNAL gcd_dataa, gcd_datab, gcd_result : UNSIGNED(31 DOWNTO 0);

    -- Alias for word address of Wishbone address.
    ALIAS wb_word_adr : STD_ULOGIC_VECTOR(1 DOWNTO 0) IS wb_slave_i.adr(3 DOWNTO 2);

    -- data registers
    --  > address offset 0 (word 0): dataa
    --  > address offset 8 (word 1): datab
    --  > address offset 4 (word 2): result
    SIGNAL dataa_reg, datab_reg, result_reg : UNSIGNED(31 DOWNTO 0);

    -- Wishbone bus FSM
    TYPE wb_state_t IS (WB_IDLE, WB_ACK, WB_ERR);
    SIGNAL wb_state : wb_state_t;
BEGIN

    -- Wishbone bus FSM
    --  > ACK valid writes & reads
    --  > ERR on invalid accesses
    wb_state_ff : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF wb_state = WB_IDLE THEN
                -- Bus is IDLE
                --  > strobe + valid address / access, goto ACK
                --  > invalid, goto ERR
                IF wb_slave_i.stb = '1' AND wb_slave_i.we = '1' THEN
                    CASE wb_word_adr IS
                        WHEN "00" | "01" => wb_state <= WB_ACK;
                        WHEN OTHERS => wb_state <= WB_ERR;
                    END CASE;
                ELSIF wb_slave_i.stb = '1' AND wb_slave_i.we = '0' THEN
                    CASE wb_word_adr IS
                        WHEN "10" => wb_state <= WB_ACK;
                        WHEN OTHERS => wb_state <= WB_ERR;
                    END CASE;
                END IF;
            ELSE
                -- Bus is either in ACK or ERR
                --  > goto IDLE, output logic generates the correct signals 
                wb_state <= WB_IDLE;
            END IF;
        END IF;
    END PROCESS wb_state_ff;

    wb_slave_o.ack <= '1' WHEN wb_state = WB_ACK ELSE
    '0';
    wb_slave_o.err <= '1' WHEN wb_state = WB_ERR ELSE
    '0';

    -- Access dataa register at write to word 0 offset.
    dataa_reg_access : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF wb_slave_i.stb = '1' AND wb_slave_i.we = '1' AND wb_word_adr = "00" THEN
                dataa_reg <= UNSIGNED(wb_slave_i.dat);
            END IF;
        END IF;
    END PROCESS dataa_reg_access;
    gcd_dataa <= dataa_reg;

    -- Access datab register at write to word 1 offset.
    datab_reg_access : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF wb_slave_i.stb = '1' AND wb_slave_i.we = '1' AND wb_word_adr = "01" THEN
                datab_reg <= UNSIGNED(wb_slave_i.dat);
            END IF;
        END IF;
    END PROCESS datab_reg_access;
    gcd_datab <= datab_reg;

    -- Access result register at read from word 2 offset.
    -- Actually, wishbone output data is always connected to result register but
    -- the above FSM only acks accesses at word 2 offset. Write accesses to word
    -- 0 reset the result.
    result_reg_access : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF wb_slave_i.stb = '1' AND wb_slave_i.we = '1' AND wb_word_adr = "00" THEN
                result_reg <= (OTHERS => '1');
            ELSIF gcd_done = '1' THEN
                result_reg <= gcd_result;
            END IF;
        END IF;
    END PROCESS result_reg_access;
    wb_slave_o.dat <= STD_ULOGIC_VECTOR(result_reg); -- always forward

    -- Trigger start of algorithm on write to datab (word 1).
    start_trigger : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF wb_slave_i.stb = '1' AND wb_slave_i.we = '1' AND wb_word_adr = "01" THEN
                gcd_start <= '1';
            ELSE
                gcd_start <= '0';
            END IF;
        END IF;
    END PROCESS start_trigger;

    -- GCD Accelerator --
    gcb_inst : gcd
    GENERIC MAP(
        NBITS => 32 -- width of data
    )
    PORT MAP(
        clk    => clk_i,     -- clock of the algorithm
        clk_en => '1',       -- clock enable of the algorithm
        start  => gcd_start, -- strobe to start the algorithm
        reset  => gcd_reset, -- reset of the algorithm
        dataa  => gcd_dataa, -- first input number
        datab  => gcd_datab, -- second input number
        done   => gcd_done,  -- strobe to signal that the algorithm is done
        ready  => OPEN,      -- signal that the block is ready for a new calculation
        result => gcd_result -- calculated result
    );

    gcd_reset <= NOT rstn_i;

END ARCHITECTURE no_target_specific;
