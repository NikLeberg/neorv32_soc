-- =============================================================================
-- File:                    wbp_xbar.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  wbp_xbar
--
-- Description:             Wishbone interconnect for pipelined multi master
--                          multi slave bus topology. Many to many. Masters get
--                          equal statistical priorities. Arbitration is done in
--                          round-robin fashion.
--
-- Changes:                 0.1, 2024-08-19, leuen4
--                              initial version
--                          0.2, 2024-10-05, leuen4
--                              assert `err` signal only for one cycle
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.wbp_pkg.ALL;

ENTITY wbp_xbar IS
    GENERIC (
        -- General --
        N_MASTERS  : POSITIVE  := 5; -- number of connected masters
        N_SLAVES   : POSITIVE  := 3; -- number of connected slaves
        MEMORY_MAP : wbp_map_t := (
            0 => (x"0000_0000", 1 * 1024),
            1 => (x"8000_0000", 32 * 1024 * 1024),
            2 => (x"f000_0000", 64)) -- memory map of address space (for this crossbar)
    );
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, syn
        -- Wishbone master interface(s) --
        wbp_masters_mosi : IN wbp_mosi_arr_t(N_MASTERS - 1 DOWNTO 0);
        wbp_masters_miso : OUT wbp_miso_arr_t(N_MASTERS - 1 DOWNTO 0);
        -- Wishbone slave interface(s) --
        wbp_slaves_mosi : OUT wbp_mosi_arr_t(N_SLAVES - 1 DOWNTO 0);
        wbp_slaves_miso : IN wbp_miso_arr_t(N_SLAVES - 1 DOWNTO 0)
    );
END ENTITY wbp_xbar;

ARCHITECTURE no_target_specific OF wbp_xbar IS
    TYPE matrix_t IS ARRAY(N_SLAVES - 1 DOWNTO 0) OF STD_ULOGIC_VECTOR(N_MASTERS - 1 DOWNTO 0);
    SIGNAL requested, granted, granted_next, granted_last : matrix_t := (OTHERS => (OTHERS => '0'));

    SIGNAL request_error : STD_ULOGIC_VECTOR(N_MASTERS - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL request_error_reg : STD_ULOGIC_VECTOR(N_MASTERS - 1 DOWNTO 0) := (OTHERS => '0');

    SIGNAL masters_miso : wbp_miso_arr_t(N_MASTERS - 1 DOWNTO 0);
    SIGNAL slaves_mosi : wbp_mosi_arr_t(N_SLAVES - 1 DOWNTO 0);
BEGIN
    -- Check configuration.
    ASSERT N_SLAVES = MEMORY_MAP'length
    REPORT "Wishbone config error: Number of slaves does not match with memory map definition."
        SEVERITY failure;

    -- Coarse decode address requests of masters.
    coarse_decode_proc : PROCESS (wbp_masters_mosi) IS
        CONSTANT msb : NATURAL := WBP_ADDRESS_WIDTH - 1; -- upper bound of address
        VARIABLE lsb : NATURAL := 0; -- lower bound of address, depends on slave
    BEGIN
        -- Loop over all slaves and check the MSBs of the address with their entry
        -- in the memory map.
        FOR s IN 0 TO N_SLAVES - 1 LOOP
            lsb := wbp_get_slave_address_range(MEMORY_MAP(s)); -- lower bound
            -- Loop over all masters and check if they want to access this slave.
            FOR m IN 0 TO N_MASTERS - 1 LOOP
                IF wbp_masters_mosi(m).adr(msb DOWNTO lsb) = MEMORY_MAP(s).BASE_ADDRESS(msb DOWNTO lsb) THEN
                    -- Mark slave as eventually being requested by this master.
                    requested(s)(m) <= wbp_masters_mosi(m).cyc;
                ELSE
                    requested(s)(m) <= '0';
                END IF;
            END LOOP;
        END LOOP;
    END PROCESS coarse_decode_proc;

    -- Detect request errors.
    --
    -- If a master has an active transmission but is not requesting any of the
    -- configured slaves, its an error.
    request_error_proc : PROCESS (clk_i) IS
        FUNCTION is_requesting_any_slave (
            request : matrix_t;
            master : NATURAL
        ) RETURN BOOLEAN IS
        BEGIN
            FOR s IN 0 TO N_SLAVES - 1 LOOP
                IF request(s)(master) = '1' THEN
                    RETURN TRUE;
                END IF;
            END LOOP;
            RETURN FALSE;
        END FUNCTION;
    BEGIN
        IF rising_edge(clk_i) THEN
            FOR m IN 0 TO N_MASTERS - 1 LOOP
                IF is_requesting_any_slave(requested, m) THEN
                    request_error(m) <= '0';
                ELSE
                    request_error(m) <= wbp_masters_mosi(m).cyc;
                END IF;
            END LOOP;
            request_error_reg <= request_error;
        END IF;
    END PROCESS request_error_proc;

    -- Arbitrate requests to same slaves.
    request_arbitration_gen : FOR s IN 0 TO N_SLAVES - 1 GENERATE
        request_arbiter_inst : ENTITY work.arb_round_robin
            GENERIC MAP(
                NUM => N_MASTERS
            )
            PORT MAP(
                req  => requested(s),
                prev => granted_last(s),
                ack  => granted_next(s)
            );
    END GENERATE request_arbitration_gen;
    request_arbitration_proc : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF rstn_i = '0' THEN
                granted <= (OTHERS => (OTHERS => '0'));
            ELSE
                FOR s IN 0 TO N_SLAVES - 1 LOOP
                    IF slaves_mosi(s).cyc = '0' THEN
                        granted(s) <= granted_next(s);
                    END IF;
                END LOOP;
            END IF;
        END IF;
    END PROCESS request_arbitration_proc;

    -- Store which master did access a slave at last.
    --
    -- Slave is ready for new master if previous access is finished.
    grant_last_proc : PROCESS (clk_i) IS
    BEGIN
        IF rising_edge(clk_i) THEN
            IF rstn_i = '0' THEN
                granted_last <= (OTHERS => (OTHERS => '0'));
            ELSE
                FOR s IN 0 TO N_SLAVES - 1 LOOP
                    IF slaves_mosi(s).cyc = '0' THEN
                        granted_last(s) <= granted(s);
                    END IF;
                END LOOP;
            END IF;
        END IF;
    END PROCESS grant_last_proc;

    -- Connect master request to slave.
    conn_mosi_proc : PROCESS (granted, wbp_masters_mosi) IS
        -- Compute the master number from the given grant matrix.
        FUNCTION get_master_num (grant : matrix_t; slave : NATURAL) RETURN NATURAL IS
        BEGIN
            FOR m IN 0 TO N_MASTERS - 1 LOOP
                IF grant(slave)(m) = '1' THEN
                    RETURN m;
                END IF;
            END LOOP;
            RETURN N_MASTERS; -- invalid master
        END FUNCTION;
        VARIABLE master_num : NATURAL := N_MASTERS;
        CONSTANT master_idle : wbp_mosi_sig_t := (
            cyc => '0', stb => '0', adr => (OTHERS => '0'), we => '0',
            sel => (OTHERS => '0'), dat => (OTHERS => '0')
        );
    BEGIN
        FOR s IN 0 TO N_SLAVES - 1 LOOP
            master_num := get_master_num(granted, s);
            IF master_num /= N_MASTERS THEN
                slaves_mosi(s) <= wbp_masters_mosi(master_num);
            ELSE
                slaves_mosi(s) <= master_idle;
            END IF;
        END LOOP;
    END PROCESS conn_mosi_proc;

    -- Connect slave response to master.
    conn_miso_proc : PROCESS (granted, wbp_slaves_miso, request_error, request_error_reg) IS
        -- Compute the slave number from the given grant matrix.
        FUNCTION get_slave_num (grant : matrix_t; master : NATURAL) RETURN NATURAL IS
        BEGIN
            FOR s IN 0 TO N_SLAVES - 1 LOOP
                IF grant(s)(master) = '1' THEN
                    RETURN s;
                END IF;
            END LOOP;
            RETURN N_SLAVES; -- invalid slave
        END FUNCTION;
        VARIABLE slave_num : NATURAL := N_SLAVES;
        CONSTANT slave_idle : wbp_miso_sig_t := (
            stall => '1', ack => '0', err => '0', dat => (OTHERS => '0')
        );
        CONSTANT slave_err : wbp_miso_sig_t := (
            stall => '0', ack => '0', err => '1', dat => (OTHERS => '0')
        );
    BEGIN
        FOR m IN 0 TO N_MASTERS - 1 LOOP
            slave_num := get_slave_num(granted, m);
            IF slave_num /= N_SLAVES THEN
                masters_miso(m) <= wbp_slaves_miso(slave_num);
            ELSIF request_error(m) = '1' AND request_error_reg(m) = '0' THEN
                masters_miso(m) <= slave_err;
            ELSE
                masters_miso(m) <= slave_idle;
            END IF;
        END LOOP;
    END PROCESS conn_miso_proc;

    wbp_slaves_mosi <= slaves_mosi;
    wbp_masters_miso <= masters_miso;

END ARCHITECTURE no_target_specific;
