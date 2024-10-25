-- =============================================================================
-- File:                    wb_crossbar_rr.vhdl
--
-- Entity:                  wb_crossbar_rr
--
-- Description:             Wishbone interconnect for multi master multi slave
--                          bus topology. Many to many, implemented with muxes.
--
-- Note 1:                  Masters get equal statistical priorities.
--                          Arbitration is done in round-robin fashion.
--
-- Note 2:                  Even though this entity uses a clock signal the
--                          connection between master and slave is issued with
--                          no delay.
--
-- Note 3:                  The `MEMORY_MAP` generic should contain the
--                          addresses of the slave connected to this crossbar.
--                          Each access of the masters that falls not into those
--                          ranges are forwarded to the `others` slave port.
--                          Route it through another crossbar or mux intercon.
--                          This can be used to route to less used slaves like
--                          IO with a simple mux and helps to keep this crossbar
--                          small. If the interface is terminated with an error
--                          state, note that that error slave is shared and
--                          arbitrated over. This will delay error handling.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.4
--
-- Changes:                 0.1, 2023-04-13, NikLeberg
--                              initial version
--                          0.2, 2023-04-19, NikLeberg
--                              add `other` slaves interfaces to forward
--                              unmapped slaves to other interconnects or error
--                          0.3, 2023-08-02, NikLeberg
--                              fixed `other` slave interface: was not connected
--                              at all and could not be simulated
--                          0.4, 2023-09-30, NikLeberg
--                              copy of wb_crossbar with round-robin arbiter
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_crossbar_rr IS
    GENERIC (
        -- General --
        N_MASTERS  : POSITIVE; -- number of connected masters
        N_SLAVES   : POSITIVE; -- number of connected slaves
        MEMORY_MAP : wb_map_t  -- memory map of address space (for this crossbar)
    );
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, syn
        -- Wishbone master interface(s) --
        wb_masters_i : IN wb_req_arr_t(N_MASTERS - 1 DOWNTO 0);
        wb_masters_o : OUT wb_resp_arr_t(N_MASTERS - 1 DOWNTO 0);
        -- Wishbone slave interface(s) --
        wb_slaves_o : OUT wb_req_arr_t(N_SLAVES - 1 DOWNTO 0);
        wb_slaves_i : IN wb_resp_arr_t(N_SLAVES - 1 DOWNTO 0);
        -- Other unmapped Wishbone slaves interface --
        wb_others_o : OUT wb_req_sig_t;
        wb_others_i : IN wb_resp_sig_t
    );
END ENTITY wb_crossbar_rr;

ARCHITECTURE no_target_specific OF wb_crossbar_rr IS
    CONSTANT address_ranges : natural_arr_t := wb_get_slave_address_ranges(MEMORY_MAP);

    -- Vector types for common signal needs, with additional slaves for the
    -- "others" interface.
    SUBTYPE master_vector_t IS STD_ULOGIC_VECTOR(N_MASTERS - 1 DOWNTO 0);
    TYPE slave_vector_t IS ARRAY(N_SLAVES DOWNTO 0) OF master_vector_t;

    -- Combined slave connections from N_SLAVES and "others" slaves.
    SIGNAL slaves_in : wb_resp_arr_t(N_SLAVES DOWNTO 0);
    SIGNAL slaves_out : wb_req_arr_t(N_SLAVES DOWNTO 0);

    -- Dummy master to idle the bus for unconnected slaves.
    CONSTANT master_idle : wb_req_sig_t := (
        adr => (OTHERS => '0'), dat => (OTHERS => '0'), we => '0',
        sel => (OTHERS => '0'), stb => '0', cyc => '0');
    -- Dummy slave to idle the bus for unconnected masters.
    CONSTANT slave_idle : wb_resp_sig_t := (ack => '0', err => '0', dat => (OTHERS => '0'));

    -- Mapping of which slave is requested by which master.
    SIGNAL slave_request : slave_vector_t := (OTHERS => (OTHERS => '0'));
    -- Request acknowledges of slave arbiters.
    SIGNAL slave_ack : slave_vector_t := (OTHERS => (OTHERS => '0'));
    -- Request grants for slave arbiters.
    SIGNAL slave_grant : slave_vector_t := (OTHERS => (OTHERS => '0'));

    -- Signals for grant indices that are used to connect masters to slaves.
    CONSTANT MASTER_INVALID : NATURAL := N_MASTERS;
    CONSTANT SLAVE_INVALID : NATURAL := N_SLAVES + 1;
    TYPE integer_arr_t IS ARRAY (INTEGER RANGE <>) OF INTEGER;
    SIGNAL mgrant : integer_arr_t(N_SLAVES DOWNTO 0) := (OTHERS => MASTER_INVALID); -- granted master for each slave
    SIGNAL sgrant : integer_arr_t(N_MASTERS - 1 DOWNTO 0) := (OTHERS => SLAVE_INVALID); -- granted slave for each master

BEGIN
    -- Check wishbone configuration.
    ASSERT WB_ADDRESS_WIDTH MOD 8 = 0
    REPORT "Wishbone config error: Width of address bus needs to be a multiple of 8."
        SEVERITY error;
    ASSERT WB_DATA_WIDTH MOD 8 = 0
    REPORT "Wishbone config error: Width of data bus needs to be a multiple of 8."
        SEVERITY error;
    ASSERT N_SLAVES = MEMORY_MAP'length
    REPORT "Wishbone config error: Number of slaves does not match with memory map definition."
        SEVERITY error;

    -- Coarse decode address requests of masters.
    coarse_decode : PROCESS (wb_masters_i) IS
        CONSTANT slave_none : STD_ULOGIC_VECTOR(N_SLAVES - 1 DOWNTO 0) := (OTHERS => '0');
        CONSTANT msb_adr : NATURAL := WB_ADDRESS_WIDTH - 1; -- upper bound of address
        VARIABLE lsb_adr : NATURAL := 0; -- lower bound of address, depends on slave
    BEGIN
        slave_request <= (OTHERS => (OTHERS => '0'));

        -- Assume master requests access to the others interface. This is
        -- cleared when an ordinary slave is accessed.
        FOR m IN 0 TO N_MASTERS - 1 LOOP
            slave_request(N_SLAVES)(m) <= wb_masters_i(m).cyc;
        END LOOP;

        -- Loop over all slaves and check the MSB of the address with
        -- their entry in the memory map.
        FOR s IN 0 TO N_SLAVES - 1 LOOP
            lsb_adr := address_ranges(s); -- lower bound
            -- Loop over all masters and check if they want to access this slave.
            FOR m IN 0 TO N_MASTERS - 1 LOOP
                -- Is master even transmitting?
                IF wb_masters_i(m).cyc = '1' THEN
                    IF wb_masters_i(m).adr(msb_adr DOWNTO lsb_adr) = MEMORY_MAP(s).BASE_ADDRESS(msb_adr DOWNTO lsb_adr) THEN
                        -- Mark slave as being requested by this master.
                        slave_request(s)(m) <= wb_masters_i(m).cyc;
                        -- Clear asumption of request for others interface.
                        slave_request(N_SLAVES)(m) <= '0';
                    END IF;
                END IF;
            END LOOP;
        END LOOP;
    END PROCESS coarse_decode;

    -- Round-robin style arbiter.
    round_robin_arbiter : FOR s IN 0 TO N_SLAVES GENERATE
        round_robin_arbiter_inst : ENTITY work.arb_round_robin
            GENERIC MAP(
                NUM => N_MASTERS -- how many requests to arbitrate
            )
            PORT MAP(
                req  => slave_request(s), -- requests
                prev => slave_grant(s),   -- to whom was last granted access
                ack  => slave_ack(s)      -- acknowledge of request
            );
    END GENERATE round_robin_arbiter;

    -- Store which master did access a slave at last. 
    grant_memory : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            FOR s IN 0 TO N_SLAVES LOOP
                -- Slave is ready for new master if previous access is finished.
                IF slaves_out(s).cyc = '0' THEN
                    slave_grant(s) <= slave_ack(s);
                END IF;
            END LOOP;
        END IF;
    END PROCESS grant_memory;

    -- Compute indices of granted connections.
    grant_index : PROCESS (slave_grant) IS
        -- Extract a vector of the masters regardless of slaves. i.e. the second
        -- dimension of slave_grant(*)(m).
        FUNCTION extract(matrix : slave_vector_t; master : NATURAL) RETURN STD_ULOGIC_VECTOR IS
            VARIABLE tmp : STD_ULOGIC_VECTOR(N_SLAVES DOWNTO 0);
        BEGIN
            FOR s IN 0 TO N_SLAVES LOOP
                tmp(s) := matrix(s)(master);
            END LOOP;
            RETURN tmp;
        END FUNCTION extract;
        -- What bitnumber is set? If none, use the given default.
        FUNCTION bit_num(vector : STD_ULOGIC_VECTOR; def : NATURAL) RETURN NATURAL IS
        BEGIN
            FOR i IN vector'RANGE LOOP
                IF vector(i) = '1' THEN
                    RETURN i;
                END IF;
            END LOOP;
            RETURN def;
        END FUNCTION bit_num;
    BEGIN
        FOR s IN 0 TO N_SLAVES LOOP
            mgrant(s) <= bit_num(slave_grant(s), MASTER_INVALID);
        END LOOP;
        FOR m IN 0 TO N_MASTERS - 1 LOOP
            sgrant(m) <= bit_num(extract(slave_grant, m), SLAVE_INVALID);
        END LOOP;
    END PROCESS grant_index;

    -- Connect the masters to the slaves.
    mux : PROCESS (wb_masters_i, slaves_in, sgrant, mgrant) IS
    BEGIN
        -- Connect the master and slave when the crossbar switch was granted.
        FOR m IN 0 TO N_MASTERS - 1 LOOP
            IF sgrant(m) = SLAVE_INVALID THEN
                wb_masters_o(m) <= slave_idle;
            ELSE
                wb_masters_o(m) <= slaves_in(sgrant(m));
            END IF;
        END LOOP;
        FOR s IN 0 TO N_SLAVES LOOP
            IF mgrant(s) = MASTER_INVALID THEN
                slaves_out(s) <= master_idle;
            ELSE
                slaves_out(s) <= wb_masters_i(mgrant(s));
            END IF;
        END LOOP;
    END PROCESS mux;

    -- Concatenate real slaves and "other" slaves into vector for easy handling.
    wb_slaves_o <= slaves_out(N_SLAVES - 1 DOWNTO 0);
    wb_others_o <= slaves_out(N_SLAVES);
    slaves_in <= (wb_others_i & wb_slaves_i);

END ARCHITECTURE no_target_specific;
