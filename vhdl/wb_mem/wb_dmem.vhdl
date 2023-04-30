-- =============================================================================
-- File:                    wb_dmem.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  wb_dmem
--
-- Description:             Wishbone accessible data memory (DMEM). Implemented
--                          as dual-port RAM each port gets made accessible
--                          though one Wishbone slave channel. The idea is that
--                          two masters (i.e. CPUs) can access the data memory
--                          at the same time.
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
-- Changes:                 0.1, 2023-04-16, leuen4
--                              initial version
--                          0.2, 2023-04-30, leuen4
--                              add simulation specific architecture
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_dmem IS
    GENERIC (
        DMEM_SIZE : NATURAL := 16 * 1024 -- size of data memory in bytes
    );
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, async

        -- Wishbone slave interfaces --
        wb_slaves_i : IN wb_slave_rx_arr_t(1 DOWNTO 0); -- control and data from master to slave
        wb_slaves_o : OUT wb_slave_tx_arr_t(1 DOWNTO 0) -- status and data from slave to master
    );
END ENTITY wb_dmem;

ARCHITECTURE synthesis OF wb_dmem IS

    -- Type for memory with 8-bit entries, required to be of resolved type, as
    -- otherwise Quartus can't map it to dual-port RAM.
    TYPE mem8_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(07 DOWNTO 0);

    -- RAM - not initialized at all --
    SIGNAL mem_ram_b0 : mem8_t(0 TO DMEM_SIZE/4 - 1);
    SIGNAL mem_ram_b1 : mem8_t(0 TO DMEM_SIZE/4 - 1);
    SIGNAL mem_ram_b2 : mem8_t(0 TO DMEM_SIZE/4 - 1);
    SIGNAL mem_ram_b3 : mem8_t(0 TO DMEM_SIZE/4 - 1);

    -- local signals --
    SIGNAL adr_a, adr_b : STD_ULOGIC_VECTOR(index_size_f(DMEM_SIZE/4) - 1 DOWNTO 0);
    SIGNAL ack : STD_ULOGIC_VECTOR(1 DOWNTO 0);

    -- read data --
    SIGNAL mem_ram_b0_rd_a, mem_ram_b1_rd_a, mem_ram_b2_rd_a, mem_ram_b3_rd_a : STD_ULOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL mem_ram_b0_rd_b, mem_ram_b1_rd_b, mem_ram_b2_rd_b, mem_ram_b3_rd_b : STD_ULOGIC_VECTOR(7 DOWNTO 0);

BEGIN

    -- Implement IMEM as not-initialized dual-port RAM (port A) -------------------------------
    -- -------------------------------------------------------------------------------------------
    adr_a <= wb_slaves_i(0).adr(index_size_f(DMEM_SIZE/4) + 1 DOWNTO 2); -- word aligned
    proc_port_a : PROCESS (clk_i)
    BEGIN
        IF rising_edge(clk_i) THEN
            -- read-after-write behavior is implicitly "read old"
            IF wb_slaves_i(0).stb = '1' THEN -- reduce switching activity when not accessed
                IF wb_slaves_i(0).we = '1' THEN
                    IF wb_slaves_i(0).sel(0) = '1' THEN -- byte 0
                        mem_ram_b0(to_integer(unsigned(adr_a))) <= STD_LOGIC_VECTOR(wb_slaves_i(0).dat(07 DOWNTO 00));
                    END IF;
                    IF wb_slaves_i(0).sel(1) = '1' THEN -- byte 1
                        mem_ram_b1(to_integer(unsigned(adr_a))) <= STD_LOGIC_VECTOR(wb_slaves_i(0).dat(15 DOWNTO 08));
                    END IF;
                    IF wb_slaves_i(0).sel(2) = '1' THEN -- byte 2
                        mem_ram_b2(to_integer(unsigned(adr_a))) <= STD_LOGIC_VECTOR(wb_slaves_i(0).dat(23 DOWNTO 16));
                    END IF;
                    IF wb_slaves_i(0).sel(3) = '1' THEN -- byte 3
                        mem_ram_b3(to_integer(unsigned(adr_a))) <= STD_LOGIC_VECTOR(wb_slaves_i(0).dat(31 DOWNTO 24));
                    END IF;
                END IF;
            END IF;
            -- always read, quartus otherwise can't infer
            mem_ram_b0_rd_a <= STD_ULOGIC_VECTOR(mem_ram_b0(to_integer(unsigned(adr_a))));
            mem_ram_b1_rd_a <= STD_ULOGIC_VECTOR(mem_ram_b1(to_integer(unsigned(adr_a))));
            mem_ram_b2_rd_a <= STD_ULOGIC_VECTOR(mem_ram_b2(to_integer(unsigned(adr_a))));
            mem_ram_b3_rd_a <= STD_ULOGIC_VECTOR(mem_ram_b3(to_integer(unsigned(adr_a))));
        END IF;
    END PROCESS proc_port_a;

    -- Implement IMEM as not-initialized dual-port RAM (port B) -------------------------------
    -- -------------------------------------------------------------------------------------------
    adr_b <= wb_slaves_i(1).adr(index_size_f(DMEM_SIZE/4) + 1 DOWNTO 2); -- word aligned
    proc_port_b : PROCESS (clk_i)
    BEGIN
        IF rising_edge(clk_i) THEN
            -- read-after-write behavior is implicitly "read old"
            IF wb_slaves_i(1).stb = '1' THEN -- reduce switching activity when not accessed
                IF wb_slaves_i(1).we = '1' THEN
                    IF wb_slaves_i(1).sel(0) = '1' THEN -- byte 0
                        mem_ram_b0(to_integer(unsigned(adr_b))) <= STD_LOGIC_VECTOR(wb_slaves_i(1).dat(07 DOWNTO 00));
                    END IF;
                    IF wb_slaves_i(1).sel(1) = '1' THEN -- byte 1
                        mem_ram_b1(to_integer(unsigned(adr_b))) <= STD_LOGIC_VECTOR(wb_slaves_i(1).dat(15 DOWNTO 08));
                    END IF;
                    IF wb_slaves_i(1).sel(2) = '1' THEN -- byte 2
                        mem_ram_b2(to_integer(unsigned(adr_b))) <= STD_LOGIC_VECTOR(wb_slaves_i(1).dat(23 DOWNTO 16));
                    END IF;
                    IF wb_slaves_i(1).sel(3) = '1' THEN -- byte 3
                        mem_ram_b3(to_integer(unsigned(adr_b))) <= STD_LOGIC_VECTOR(wb_slaves_i(1).dat(31 DOWNTO 24));
                    END IF;
                END IF;
            END IF;
            -- always read, quartus otherwise can't infer
            mem_ram_b0_rd_b <= STD_ULOGIC_VECTOR(mem_ram_b0(to_integer(unsigned(adr_b))));
            mem_ram_b1_rd_b <= STD_ULOGIC_VECTOR(mem_ram_b1(to_integer(unsigned(adr_b))));
            mem_ram_b2_rd_b <= STD_ULOGIC_VECTOR(mem_ram_b2(to_integer(unsigned(adr_b))));
            mem_ram_b3_rd_b <= STD_ULOGIC_VECTOR(mem_ram_b3(to_integer(unsigned(adr_b))));
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
    wb_slaves_o(0).dat <= mem_ram_b3_rd_a & mem_ram_b2_rd_a & mem_ram_b1_rd_a & mem_ram_b0_rd_a;
    wb_slaves_o(1).dat <= mem_ram_b3_rd_b & mem_ram_b2_rd_b & mem_ram_b1_rd_b & mem_ram_b0_rd_b;
    -- Master may abort the transmission, gate ack and err signals.
    wb_slaves_o(0).ack <= ack(0) AND wb_slaves_i(0).stb;
    wb_slaves_o(0).err <= '0';
    wb_slaves_o(1).ack <= ack(1) AND wb_slaves_i(1).stb;
    wb_slaves_o(1).err <= '0';

END ARCHITECTURE synthesis;

ARCHITECTURE simulation OF wb_dmem IS

    -- RAM - not initialized at all --
    SIGNAL mem_ram_b0 : mem8_t(0 TO DMEM_SIZE/4 - 1);
    SIGNAL mem_ram_b1 : mem8_t(0 TO DMEM_SIZE/4 - 1);
    SIGNAL mem_ram_b2 : mem8_t(0 TO DMEM_SIZE/4 - 1);
    SIGNAL mem_ram_b3 : mem8_t(0 TO DMEM_SIZE/4 - 1);

    -- local signals --
    SIGNAL adr_a, adr_b : STD_ULOGIC_VECTOR(index_size_f(DMEM_SIZE/4) - 1 DOWNTO 0);
    SIGNAL ack : STD_ULOGIC_VECTOR(1 DOWNTO 0);

    -- read data --
    SIGNAL mem_ram_b0_rd_a, mem_ram_b1_rd_a, mem_ram_b2_rd_a, mem_ram_b3_rd_a : STD_ULOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL mem_ram_b0_rd_b, mem_ram_b1_rd_b, mem_ram_b2_rd_b, mem_ram_b3_rd_b : STD_ULOGIC_VECTOR(7 DOWNTO 0);

BEGIN

    -- Implement IMEM as not-initialized dual-port RAM ----------------------------------------
    -- -------------------------------------------------------------------------------------------
    adr_a <= wb_slaves_i(0).adr(index_size_f(DMEM_SIZE/4) + 1 DOWNTO 2); -- word aligned
    adr_b <= wb_slaves_i(1).adr(index_size_f(DMEM_SIZE/4) + 1 DOWNTO 2); -- word aligned
    proc_port_a : PROCESS (clk_i)
    BEGIN
        IF rising_edge(clk_i) THEN
            -- port A --
            -- read-after-write behavior is implicitly "read old"
            IF wb_slaves_i(0).stb = '1' THEN -- reduce switching activity when not accessed
                IF wb_slaves_i(0).we = '1' THEN
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
            END IF;
            -- always read
            mem_ram_b0_rd_a <= mem_ram_b0(to_integer(unsigned(adr_a)));
            mem_ram_b1_rd_a <= mem_ram_b1(to_integer(unsigned(adr_a)));
            mem_ram_b2_rd_a <= mem_ram_b2(to_integer(unsigned(adr_a)));
            mem_ram_b3_rd_a <= mem_ram_b3(to_integer(unsigned(adr_a)));

            -- port B --
            -- read-after-write behavior is implicitly "read old"
            IF wb_slaves_i(1).stb = '1' THEN -- reduce switching activity when not accessed
                IF wb_slaves_i(1).we = '1' THEN
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
