-- =============================================================================
-- File:                    wb_crossbar.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  wb_crossbar
--
-- Description:             Wishbone interconnect for multi master multi slave
--                          bus topology. Many to many, implemented with muxes.
--
-- Note 1:                  The memory map of the system permits to contain the
--                          same slave address multiple times. This allows for
--                          dual channel access to the same slave for example if
--                          the slave is a dual port RAM.
--
-- Note 2:                  Masters get priority based on their index. Index 0
--                          has highest priority, index N_MASTERS - 1 the least.
--
-- Note 3:                  Even though this entity uses a clock signal the
--                          connection between master and slave is issued with
--                          no delay.
--
-- Changes:                 0.1, 2023-04-13, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_crossbar IS
    GENERIC (
        -- General --
        N_MASTERS  : NATURAL; -- number of connected masters
        N_SLAVES   : NATURAL; -- number of connected slaves
        MEMORY_MAP : wb_map_t -- memory map of address space
    );
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, asyn
        -- Wishbone master interface(s) --
        wb_masters_i : IN wb_master_tx_arr_t(N_MASTERS - 1 DOWNTO 0);
        wb_masters_o : OUT wb_master_rx_arr_t(N_MASTERS - 1 DOWNTO 0);
        -- Wishbone slave interface(s) --
        wb_slaves_o : OUT wb_slave_rx_arr_t(N_SLAVES - 1 DOWNTO 0);
        wb_slaves_i : IN wb_slave_tx_arr_t(N_SLAVES - 1 DOWNTO 0)
    );
END ENTITY wb_crossbar;

ARCHITECTURE no_target_specific OF wb_crossbar IS
    CONSTANT coarse_decode_msb_bit_nums : natural_arr_t := wb_calc_coarse_decode_msb_bit_nums(MEMORY_MAP);

    -- Vector types for common signal needs.
    SUBTYPE slave_vector_t IS STD_ULOGIC_VECTOR(N_SLAVES - 1 DOWNTO 0);
    TYPE master_vector_t IS ARRAY (N_MASTERS - 1 DOWNTO 0) OF slave_vector_t;

    -- Dummy master to idle the bus for unconnected slaves.
    CONSTANT master_idle : wb_master_tx_sig_t := (
        adr => (OTHERS => '0'), dat => (OTHERS => '0'), we => '0',
        sel => (OTHERS => '0'), stb => '0', cyc => '0');
    -- Dummy slave to idle the bus for unconnected masters.
    CONSTANT slave_idle : wb_master_rx_sig_t := (ack => '0', err => '0', dat => (OTHERS => '0'));
    -- Error slave to terminate accesses that have no associated slave.
    CONSTANT slave_err : wb_master_rx_sig_t := (ack => '0', err => '1', dat => (OTHERS => '0'));

    -- Mapping of which slave can fulfill which request from master.
    SIGNAL master_request : master_vector_t := (OTHERS => (OTHERS => '0'));
    -- Mapping of which master got granted access to which slave.
    SIGNAL master_grant : master_vector_t := (OTHERS => (OTHERS => '0'));
    -- Logic signals for ripple-carry arbiter.
    SIGNAL arb_n, arb_s, arb_w, arb_e : master_vector_t := (OTHERS => (OTHERS => '0'));
    -- Lock for granted requests for as long as transactions are active.
    SIGNAL master_lock : master_vector_t := (OTHERS => (OTHERS => '0'));

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
        CONSTANT msb_adr : NATURAL := WB_ADDRESS_WIDTH - 1; -- upper bound of address
        VARIABLE lsb_adr : NATURAL := 0; -- lower bound of address, depends on slave
    BEGIN
        -- Loop over all masters to check each of their requested addresses.
        FOR m IN N_MASTERS - 1 DOWNTO 0 LOOP
            -- Default to no request.
            master_request(m) <= (OTHERS => '0');
            -- Is master even transmitting?
            IF wb_masters_i(m).cyc = '1' THEN
                -- Loop over all slaves and check the MSB of the address with
                -- their entry in the memory map.
                FOR s IN N_SLAVES - 1 DOWNTO 0 LOOP
                    lsb_adr := coarse_decode_msb_bit_nums(s); -- lower bound
                    IF wb_masters_i(m).adr(msb_adr DOWNTO lsb_adr) = MEMORY_MAP(s).BASE_ADDRESS(msb_adr DOWNTO lsb_adr) THEN
                        -- Slave matches the address. Mark it as possible slave
                        -- to fulfill request from master.
                        master_request(m)(s) <= '1';
                    END IF;
                END LOOP;
            END IF;
        END LOOP;
    END PROCESS coarse_decode;

    -- Modelled after paper "VHDL IMPLEMENTATION OF A HIGH-SPEED SYMMETRIC
    -- CROSSBAR SWITCH" by Maryam Keyvani, University of Tehran
    -- Source: https://www.sfu.ca/~ljilja/cnl/pdf/keyvani.pdf
    -- Modified to lock granted connections in place while transactions are
    -- active. Otherwise a higher prioritized master would take away the slave
    -- from lower priority master while he is still accessing it.
    ripple_carry_arbiter : PROCESS (master_request, master_grant, master_lock, arb_n, arb_s, arb_w, arb_e) IS
        -- Check if this slave is locked by any master.
        FUNCTION slave_locked(locks : master_vector_t; slave : INTEGER) RETURN STD_ULOGIC IS
        BEGIN
            FOR m IN 0 TO N_MASTERS - 1 LOOP
                IF locks(m)(slave) = '1' THEN
                    RETURN '0'; -- a master has locked this slave
                END IF;
            END LOOP;
            RETURN '1'; -- no master has locked this slave
        END FUNCTION slave_locked;
    BEGIN
        FOR m IN 0 TO N_MASTERS - 1 LOOP
            FOR s IN 0 TO N_SLAVES - 1 LOOP
                -- For first master row, all north connections are '1' exept if
                -- the master has a lock on a slave connection.
                -- For other rows, north = south from previous row.
                IF m = 0 THEN
                    arb_n(m)(s) <= slave_locked(master_lock, s);
                ELSE
                    arb_n(m)(s) <= arb_s(m - 1)(s);
                END IF;
                -- For first slave column, all west connections are '1'.
                -- For other columns, west = east from previous column.
                IF s = 0 THEN
                    arb_w(m)(s) <= '1';
                ELSE
                    arb_w(m)(s) <= arb_e(m)(s - 1);
                END IF;
                -- Actual arbitration cell. Grant request if line and column has
                -- no grant already. The north/sourth/east/west signals carry a
                -- '1' if they did not grant i.e. are free. If this cell grants
                -- a request a '0' is sent forward. Overrule the grant if this
                -- connection was locked, this prevents active connections on
                -- lower prioritized masters active to be taken away by other
                -- higher prioritized masters.
                master_grant(m)(s) <= (arb_n(m)(s) AND arb_w(m)(s) AND master_request(m)(s)) OR master_lock(m)(s);
                arb_s(m)(s) <= arb_n(m)(s) AND NOT master_grant(m)(s);
                arb_e(m)(s) <= arb_w(m)(s) AND NOT master_grant(m)(s);
            END LOOP;
        END LOOP;
    END PROCESS ripple_carry_arbiter;

    -- Lock grant for connections that have active communication.
    lock_memory : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF rstn_i = '0' THEN
                master_lock <= (OTHERS => (OTHERS => '0'));
            ELSE
                FOR m IN 0 TO N_MASTERS - 1 LOOP
                    FOR s IN 0 TO N_SLAVES - 1 LOOP
                        -- If this lock is inactive, activate it on first grant,
                        -- lock gets deactivated after master resets cyc signal.
                        IF master_lock(m)(s) = '0' THEN
                            IF master_grant(m)(s) = '1' THEN
                                master_lock(m)(s) <= '1';
                            END IF;
                        ELSE
                            IF wb_masters_i(m).cyc = '0' THEN
                                master_lock(m)(s) <= '0';
                            END IF;
                        END IF;
                    END LOOP;
                END LOOP;
            END IF;
        END IF;
    END PROCESS lock_memory;

    -- Connect masters to the slaves.
    mux : PROCESS (master_grant, master_request, wb_masters_i, wb_slaves_i) IS
        CONSTANT slave_none : slave_vector_t := (OTHERS => '0');
    BEGIN
        -- Default to idle bus if master or slave is not connected.
        wb_masters_o <= (OTHERS => slave_idle);
        wb_slaves_o <= (OTHERS => master_idle);

        -- Connect the master and slave when the crossbar switch was granted.
        FOR m IN 0 TO N_MASTERS - 1 LOOP
            FOR s IN 0 TO N_SLAVES - 1 LOOP
                IF master_grant(m)(s) = '1' THEN
                    wb_slaves_o(s) <= wb_masters_i(m);
                    wb_masters_o(m) <= wb_slaves_i(s);
                END IF;
            END LOOP;
        END LOOP;

        -- Issue an error condition if master tries to access nonexistant slave.
        FOR m IN 0 TO N_MASTERS - 1 LOOP
            IF wb_masters_i(m).cyc = '1' AND master_request(m) = slave_none THEN
                wb_masters_o(m) <= slave_err;
            END IF;
        END LOOP;
    END PROCESS mux;

END ARCHITECTURE no_target_specific;
