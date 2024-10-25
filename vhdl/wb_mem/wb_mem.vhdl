-- =============================================================================
-- File:                    wb_mem.vhdl
--
-- Entity:                  wb_mem
--
-- Description:             Wishbone accessible memory (MEM). Implemented as
--                          dual-port RAM each port gets made accessible through
--                          one Wishbone slave channel. The idea is that two
--                          masters (i.e. CPUs) can access the memory at the
--                          same time.
--
-- Note 1:                  Synthesizer should be inferring a synchronous dual-
--                          port RAM. Quartus Prime states successful inferring
--                          in a log message like so: "Info (19000): Inferred 1
--                          megafunctions from design logic" and "Info (276031):
--                          Inferred altsyncram megafunction from the following
--                          design logic <>"
--
-- Note 2:                  Large chunks of this file are a 1:1 copy from
--                          neorv32_dmem.default.vhd Copyright (c) 2023, Stephan
--                          Nolting. See respective file for more information.
--
-- Note 3:                  Simulators (tested: Modelsim and QuestaSim) can't
--                          handle dual-port ram that is described in two
--                          processes. But synthesis requires it like that. For
--                          this we need two architectures. See:
--                          https://community.intel.com/t5/Intel-Quartus-Prime-
--                          Software/Dual-port-RAM-in-Quartus-II-7-2-different-
--                          behavior-on-ModelSim/m-p/35356
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.3
--
-- Changes:                 0.1, 2023-04-16, NikLeberg
--                              initial version
--                          0.2, 2023-04-30, NikLeberg
--                              add simulation specific architecture
--                          0.3, 2023-09-30, NikLeberg
--                              consolidate {D,I}MEM into one entity
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_mem IS
    GENERIC (
        MEM_SIZE  : NATURAL := 16 * 1024;         -- size of memory in bytes
        MEM_IMAGE : mem32_t := (0 => x"00000000") -- initialization image of memory
    );
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, sync

        -- Wishbone slave interfaces --
        wb_slaves_i : IN wb_req_arr_t(1 DOWNTO 0);  -- control and data from master to slave
        wb_slaves_o : OUT wb_resp_arr_t(1 DOWNTO 0) -- status and data from slave to master
    );
END ENTITY wb_mem;

ARCHITECTURE synthesis OF wb_mem IS

    -- Type for memory with 8-bit entries, required to be of resolved type, as
    -- otherwise Quartus can't map it to dual-port RAM.
    TYPE mem8_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(07 DOWNTO 0);

    -- Initialize mem8_t array from mem32_t array ---------------------------------------------
    -- -------------------------------------------------------------------------------------------
    IMPURE FUNCTION mem8_init_f(init : mem32_t; depth : NATURAL; byte : NATURAL) RETURN mem8_t IS
        VARIABLE mem_v : mem8_t(0 TO depth - 1);
    BEGIN
        mem_v := (OTHERS => (OTHERS => '0')); -- [IMPORTANT] make sure remaining memory entries are set to zero
        IF (init'length > depth) THEN
            RETURN mem_v;
        END IF;
        FOR i IN 0 TO init'length - 1 LOOP -- initialize only in range of source data array
            mem_v(i) := STD_LOGIC_VECTOR(init(i)(byte * 8 + 7 DOWNTO byte * 8));
        END LOOP;
        RETURN mem_v;
    END FUNCTION mem8_init_f;

    -- RAM - initialized with application program --
    SIGNAL mem_ram_b0 : mem8_t(0 TO MEM_SIZE/4 - 1) := mem8_init_f(MEM_IMAGE, MEM_SIZE/4, 0);
    SIGNAL mem_ram_b1 : mem8_t(0 TO MEM_SIZE/4 - 1) := mem8_init_f(MEM_IMAGE, MEM_SIZE/4, 1);
    SIGNAL mem_ram_b2 : mem8_t(0 TO MEM_SIZE/4 - 1) := mem8_init_f(MEM_IMAGE, MEM_SIZE/4, 2);
    SIGNAL mem_ram_b3 : mem8_t(0 TO MEM_SIZE/4 - 1) := mem8_init_f(MEM_IMAGE, MEM_SIZE/4, 3);

    -- local signals --
    SIGNAL adr_a, adr_b : STD_ULOGIC_VECTOR(index_size_f(MEM_SIZE/4) - 1 DOWNTO 0);
    SIGNAL dat_i_a, dat_i_b, dat_o_a, dat_o_b : STD_LOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0);
    SIGNAL ack : STD_ULOGIC_VECTOR(1 DOWNTO 0);

    -- read data --
    SIGNAL mem_ram_b0_rd_a, mem_ram_b1_rd_a, mem_ram_b2_rd_a, mem_ram_b3_rd_a : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL mem_ram_b0_rd_b, mem_ram_b1_rd_b, mem_ram_b2_rd_b, mem_ram_b3_rd_b : STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN

    -- Implement IMEM as initialized dual-port RAM (port A) -------------------------------
    -- -------------------------------------------------------------------------------------------
    adr_a <= wb_slaves_i(0).adr(index_size_f(MEM_SIZE/4) + 1 DOWNTO 2); -- word aligned
    dat_i_a <= STD_LOGIC_VECTOR(wb_slaves_i(0).dat);
    proc_port_a : PROCESS (clk_i)
    BEGIN
        IF rising_edge(clk_i) THEN
            -- read-after-write behavior is implicitly "read old"
            IF wb_slaves_i(0).stb = '1' AND wb_slaves_i(0).we = '1' THEN -- reduce switching activity when not accessed
                IF wb_slaves_i(0).sel(0) = '1' THEN -- byte 0
                    mem_ram_b0(to_integer(unsigned(adr_a))) <= dat_i_a(07 DOWNTO 00);
                END IF;
                IF wb_slaves_i(0).sel(1) = '1' THEN -- byte 1
                    mem_ram_b1(to_integer(unsigned(adr_a))) <= dat_i_a(15 DOWNTO 08);
                END IF;
                IF wb_slaves_i(0).sel(2) = '1' THEN -- byte 2
                    mem_ram_b2(to_integer(unsigned(adr_a))) <= dat_i_a(23 DOWNTO 16);
                END IF;
                IF wb_slaves_i(0).sel(3) = '1' THEN -- byte 3
                    mem_ram_b3(to_integer(unsigned(adr_a))) <= dat_i_a(31 DOWNTO 24);
                END IF;
            END IF;
            -- always read, quartus otherwise can't infer
            mem_ram_b0_rd_a <= mem_ram_b0(to_integer(unsigned(adr_a)));
            mem_ram_b1_rd_a <= mem_ram_b1(to_integer(unsigned(adr_a)));
            mem_ram_b2_rd_a <= mem_ram_b2(to_integer(unsigned(adr_a)));
            mem_ram_b3_rd_a <= mem_ram_b3(to_integer(unsigned(adr_a)));
        END IF;
    END PROCESS proc_port_a;

    -- Implement IMEM as initialized dual-port RAM (port B) -------------------------------
    -- -------------------------------------------------------------------------------------------
    adr_b <= wb_slaves_i(1).adr(index_size_f(MEM_SIZE/4) + 1 DOWNTO 2); -- word aligned
    dat_i_b <= STD_LOGIC_VECTOR(wb_slaves_i(1).dat);
    proc_port_b : PROCESS (clk_i)
    BEGIN
        IF rising_edge(clk_i) THEN
            -- read-after-write behavior is implicitly "read old"
            IF wb_slaves_i(1).stb = '1' AND wb_slaves_i(1).we = '1' THEN -- reduce switching activity when not accessed
                IF wb_slaves_i(1).sel(0) = '1' THEN -- byte 0
                    mem_ram_b0(to_integer(unsigned(adr_b))) <= dat_i_b(07 DOWNTO 00);
                END IF;
                IF wb_slaves_i(1).sel(1) = '1' THEN -- byte 1
                    mem_ram_b1(to_integer(unsigned(adr_b))) <= dat_i_b(15 DOWNTO 08);
                END IF;
                IF wb_slaves_i(1).sel(2) = '1' THEN -- byte 2
                    mem_ram_b2(to_integer(unsigned(adr_b))) <= dat_i_b(23 DOWNTO 16);
                END IF;
                IF wb_slaves_i(1).sel(3) = '1' THEN -- byte 3
                    mem_ram_b3(to_integer(unsigned(adr_b))) <= dat_i_b(31 DOWNTO 24);
                END IF;
            END IF;
            -- always read, quartus otherwise can't infer
            mem_ram_b0_rd_b <= mem_ram_b0(to_integer(unsigned(adr_b)));
            mem_ram_b1_rd_b <= mem_ram_b1(to_integer(unsigned(adr_b)));
            mem_ram_b2_rd_b <= mem_ram_b2(to_integer(unsigned(adr_b)));
            mem_ram_b3_rd_b <= mem_ram_b3(to_integer(unsigned(adr_b)));
        END IF;
    END PROCESS proc_port_b;

    -- Bus Feedback ---------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    bus_feedback : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            FOR i IN 0 TO 1 LOOP
                IF rstn_i = '0' THEN
                    ack(i) <= '0';
                ELSE
                    -- Ack' an access for one clock cycle only.
                    ack(i) <= wb_slaves_i(i).stb AND NOT ack(i);
                END IF;
            END LOOP;
        END IF;
    END PROCESS bus_feedback;
    -- pack --
    dat_o_a <= mem_ram_b3_rd_a & mem_ram_b2_rd_a & mem_ram_b1_rd_a & mem_ram_b0_rd_a;
    dat_o_b <= mem_ram_b3_rd_b & mem_ram_b2_rd_b & mem_ram_b1_rd_b & mem_ram_b0_rd_b;
    wb_slaves_o(0).dat <= STD_ULOGIC_VECTOR(dat_o_a);
    wb_slaves_o(1).dat <= STD_ULOGIC_VECTOR(dat_o_b);
    -- Master may abort the transmission, gate ack and err signals.
    wb_slaves_o(0).ack <= ack(0) AND wb_slaves_i(0).stb;
    wb_slaves_o(0).err <= '0';
    wb_slaves_o(1).ack <= ack(1) AND wb_slaves_i(1).stb;
    wb_slaves_o(1).err <= '0';

END ARCHITECTURE synthesis;

ARCHITECTURE simulation OF wb_mem IS

    -- Initialize mem8_t array from mem32_t array ---------------------------------------------
    -- -------------------------------------------------------------------------------------------
    IMPURE FUNCTION mem8_init_f(init : mem32_t; depth : NATURAL; byte : NATURAL) RETURN mem8_t IS
        VARIABLE mem_v : mem8_t(0 TO depth - 1);
    BEGIN
        mem_v := (OTHERS => (OTHERS => '0')); -- [IMPORTANT] make sure remaining memory entries are set to zero
        IF (init'length > depth) THEN
            RETURN mem_v;
        END IF;
        FOR i IN 0 TO init'length - 1 LOOP -- initialize only in range of source data array
            mem_v(i) := init(i)(byte * 8 + 7 DOWNTO byte * 8);
        END LOOP;
        RETURN mem_v;
    END FUNCTION mem8_init_f;

    -- RAM - initialized with application program --
    SIGNAL mem_ram_b0 : mem8_t(0 TO MEM_SIZE/4 - 1) := mem8_init_f(MEM_IMAGE, MEM_SIZE/4, 0);
    SIGNAL mem_ram_b1 : mem8_t(0 TO MEM_SIZE/4 - 1) := mem8_init_f(MEM_IMAGE, MEM_SIZE/4, 1);
    SIGNAL mem_ram_b2 : mem8_t(0 TO MEM_SIZE/4 - 1) := mem8_init_f(MEM_IMAGE, MEM_SIZE/4, 2);
    SIGNAL mem_ram_b3 : mem8_t(0 TO MEM_SIZE/4 - 1) := mem8_init_f(MEM_IMAGE, MEM_SIZE/4, 3);

    -- local signals --
    SIGNAL adr_a, adr_b : STD_ULOGIC_VECTOR(index_size_f(MEM_SIZE/4) - 1 DOWNTO 0);
    SIGNAL ack : STD_ULOGIC_VECTOR(1 DOWNTO 0);

    -- read data --
    SIGNAL mem_ram_b0_rd_a, mem_ram_b1_rd_a, mem_ram_b2_rd_a, mem_ram_b3_rd_a : STD_ULOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL mem_ram_b0_rd_b, mem_ram_b1_rd_b, mem_ram_b2_rd_b, mem_ram_b3_rd_b : STD_ULOGIC_VECTOR(7 DOWNTO 0);

BEGIN

    -- Implement MEM as initialized dual-port RAM ----------------------------------------
    -- -------------------------------------------------------------------------------------------
    adr_a <= wb_slaves_i(0).adr(index_size_f(MEM_SIZE/4) + 1 DOWNTO 2); -- word aligned
    adr_b <= wb_slaves_i(1).adr(index_size_f(MEM_SIZE/4) + 1 DOWNTO 2); -- word aligned
    proc_port_a : PROCESS (clk_i)
    BEGIN
        IF rising_edge(clk_i) THEN
            -- port A --
            -- read-after-write behavior is implicitly "read old"
            IF wb_slaves_i(0).stb = '1' AND wb_slaves_i(0).we = '1' THEN -- reduce switching activity when not accessed
                IF wb_slaves_i(0).sel(0) = '1' THEN -- byte 0
                    mem_ram_b0(to_integer(unsigned(adr_a))) <= wb_slaves_i(0).dat(07 DOWNTO 00);
                END IF;
                IF wb_slaves_i(0).sel(1) = '1' THEN -- byte 1
                    mem_ram_b1(to_integer(unsigned(adr_a))) <= wb_slaves_i(0).dat(15 DOWNTO 08);
                END IF;
                IF wb_slaves_i(0).sel(2) = '1' THEN -- byte 2
                    mem_ram_b2(to_integer(unsigned(adr_a))) <= wb_slaves_i(0).dat(23 DOWNTO 16);
                END IF;
                IF wb_slaves_i(0).sel(3) = '1' THEN -- byte 3
                    mem_ram_b3(to_integer(unsigned(adr_a))) <= wb_slaves_i(0).dat(31 DOWNTO 24);
                END IF;
            END IF;
            -- always read
            mem_ram_b0_rd_a <= mem_ram_b0(to_integer(unsigned(adr_a)));
            mem_ram_b1_rd_a <= mem_ram_b1(to_integer(unsigned(adr_a)));
            mem_ram_b2_rd_a <= mem_ram_b2(to_integer(unsigned(adr_a)));
            mem_ram_b3_rd_a <= mem_ram_b3(to_integer(unsigned(adr_a)));

            -- port B --
            -- read-after-write behavior is implicitly "read old"
            IF wb_slaves_i(1).stb = '1' AND wb_slaves_i(1).we = '1' THEN -- reduce switching activity when not accessed
                IF wb_slaves_i(1).sel(0) = '1' THEN -- byte 0
                    mem_ram_b0(to_integer(unsigned(adr_b))) <= wb_slaves_i(1).dat(07 DOWNTO 00);
                END IF;
                IF wb_slaves_i(1).sel(1) = '1' THEN -- byte 1
                    mem_ram_b1(to_integer(unsigned(adr_b))) <= wb_slaves_i(1).dat(15 DOWNTO 08);
                END IF;
                IF wb_slaves_i(1).sel(2) = '1' THEN -- byte 2
                    mem_ram_b2(to_integer(unsigned(adr_b))) <= wb_slaves_i(1).dat(23 DOWNTO 16);
                END IF;
                IF wb_slaves_i(1).sel(3) = '1' THEN -- byte 3
                    mem_ram_b3(to_integer(unsigned(adr_b))) <= wb_slaves_i(1).dat(31 DOWNTO 24);
                END IF;
            END IF;
            -- always read, quartus otherwise can't infer
            mem_ram_b0_rd_b <= mem_ram_b0(to_integer(unsigned(adr_b)));
            mem_ram_b1_rd_b <= mem_ram_b1(to_integer(unsigned(adr_b)));
            mem_ram_b2_rd_b <= mem_ram_b2(to_integer(unsigned(adr_b)));
            mem_ram_b3_rd_b <= mem_ram_b3(to_integer(unsigned(adr_b)));
        END IF;
    END PROCESS proc_port_a;

    -- Bus Feedback ---------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    bus_feedback : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            FOR i IN 0 TO 1 LOOP
                IF rstn_i = '0' THEN
                    ack(i) <= '0';
                ELSE
                    -- Ack' an access for one clock cycle only.
                    ack(i) <= wb_slaves_i(i).stb AND NOT ack(i);
                END IF;
            END LOOP;
        END IF;
    END PROCESS bus_feedback;
    -- pack --
    wb_slaves_o(0).dat <= mem_ram_b3_rd_a & mem_ram_b2_rd_a & mem_ram_b1_rd_a & mem_ram_b0_rd_a;
    wb_slaves_o(1).dat <= mem_ram_b3_rd_b & mem_ram_b2_rd_b & mem_ram_b1_rd_b & mem_ram_b0_rd_b;
    -- Master may abort the transmission, gate ack and err signals.
    wb_slaves_o(0).ack <= ack(0) AND wb_slaves_i(0).stb;
    wb_slaves_o(0).err <= '0';
    wb_slaves_o(1).ack <= ack(1) AND wb_slaves_i(1).stb;
    wb_slaves_o(1).err <= '0';

END ARCHITECTURE simulation;
