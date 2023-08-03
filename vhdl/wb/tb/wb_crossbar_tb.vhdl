-- =============================================================================
-- File:                    wb_crossbar_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  wb_crossbar_tb
--
-- Description:             Testbench for the many to many crossbar.
--
-- Changes:                 0.1, 2023-04-14, leuen4
--                              initial version
--                          0.2, 2023-08-03, leuen4
--                              added test for `others` interface
--                              added test for address decoding
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_crossbar_tb IS
    -- Testbench needs no ports.
END ENTITY wb_crossbar_tb;

ARCHITECTURE simulation OF wb_crossbar_tb IS
    -- Component definition for device under test.
    COMPONENT wb_crossbar IS
        GENERIC (
            -- General --
            N_MASTERS  : POSITIVE; -- number of connected masters
            N_SLAVES   : POSITIVE; -- number of connected slaves
            N_OTHERS   : POSITIVE; -- number of interfaces for other slaves not in memory map
            MEMORY_MAP : wb_map_t  -- memory map of address space
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
            wb_slaves_i : IN wb_slave_tx_arr_t(N_SLAVES - 1 DOWNTO 0);
            -- Other unmapped Wishbone slave interface(s) --
            wb_other_slaves_o : OUT wb_slave_rx_arr_t(N_OTHERS - 1 DOWNTO 0);
            wb_other_slaves_i : IN wb_slave_tx_arr_t(N_OTHERS - 1 DOWNTO 0)
        );
    END COMPONENT wb_crossbar;

    -- Signals for sequential DUTs.
    CONSTANT CLK_PERIOD : DELAY_LENGTH := 20 ns; -- 50 MHz
    SIGNAL clk : STD_LOGIC := '1';
    SIGNAL rstn : STD_LOGIC := '0';
    SIGNAL tb_done, tb_done0, tb_done1, tb_done2, tb_done3 : STD_LOGIC := '0'; -- flag end of tests

    -- Signals for connecting to the DUT.
    CONSTANT WB_N_MASTERS : NATURAL := 4;
    CONSTANT WB_N_SLAVES : NATURAL := 5;
    CONSTANT WB_N_OTHERS : NATURAL := 1;
    CONSTANT WB_MEMORY_MAP : wb_map_t :=
    (
    (x"0000_0000", 1 * 1024), -- IMEM, 1 KB
    (x"0000_0000", 1 * 1024), -- IMEM, 1 KB
    (x"8000_0000", 32 * 1024 * 1024), -- SDRAM, 32 MB
    (x"8000_0000", 32 * 1024 * 1024), -- SDRAM, 32 MB
    (x"8000_0000", 32 * 1024 * 1024) -- SDRAM, 32 MB
    );
    SIGNAL wb_masters_tx : wb_master_tx_arr_t(WB_N_MASTERS - 1 DOWNTO 0) := (
        OTHERS => (cyc => '0', stb => '0', adr => x"XXXXXXXX", sel => x"f", we => '0', dat => x"XXXXXXXX")
    );
    SIGNAL wb_masters_rx : wb_master_rx_arr_t(WB_N_MASTERS - 1 DOWNTO 0);
    SIGNAL wb_slaves_rx : wb_slave_rx_arr_t(WB_N_SLAVES - 1 DOWNTO 0);
    SIGNAL wb_slaves_tx : wb_slave_tx_arr_t(WB_N_SLAVES - 1 DOWNTO 0);
    -- Error slave to terminate accesses on the others port of crossbar.
    CONSTANT wb_slave_err_o : wb_master_rx_sig_t := (ack => '0', err => '1', dat => x"deadbeef");

    -- State signals for the dummy slaves.
    signal slave_delayed_stb : std_ulogic_vector(WB_N_SLAVES - 1 DOWNTO 0) := (others => '0');

BEGIN
    -- Instantiate the device under test.
    dut : wb_crossbar
    GENERIC MAP(
        -- General --
        N_MASTERS  => WB_N_MASTERS, -- number of connected masters
        N_SLAVES   => WB_N_SLAVES,  -- number of connected slaves
        N_OTHERS   => WB_N_OTHERS,  -- number of interfaces for other slaves not in memory map
        MEMORY_MAP => WB_MEMORY_MAP -- memory map of address space
    )
    PORT MAP(
        -- Global control --
        clk_i  => clk,  -- global clock, rising edge
        rstn_i => rstn, -- global reset, low-active, asyn
        -- Wishbone master interface(s) --
        wb_masters_i => wb_masters_tx,
        wb_masters_o => wb_masters_rx,
        -- Wishbone slave interface(s) --
        wb_slaves_o => wb_slaves_rx,
        wb_slaves_i => wb_slaves_tx,
        -- Other unmapped Wishbone slave interface(s) --
        wb_other_slaves_o    => OPEN,
        wb_other_slaves_i(0) => wb_slave_err_o
    );

    -- Clock that stops after all tests are done.
    clk <= '0' WHEN tb_done = '1' ELSE
        NOT clk AFTER 0.5 * CLK_PERIOD;

    -- Power on reset the DUT, lasts two clock cycles.
    rstn <= '0', '1' AFTER 2 * CLK_PERIOD;

    -- Testbench is done after all master processes are done.
    tb_done <= tb_done0 AND tb_done1 AND tb_done2 AND tb_done3;

    master0 : PROCESS IS
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(clk);

        -- This is master0 with the highest priority, writes are not checked but
        -- reads are expected to come from a specific slave id.

        -- Read from IMEM over slave0 channel. Even tough the IMEM can be
        -- accessed from two channels (slave0 and slave1) the first one will be
        -- selected due to priority.
        wb_sim_read32(clk, wb_masters_tx(0), wb_masters_rx(0), x"0000_0000", x"0000_0000");
        -- Read from SDRAM over slave2 channel. Even tough the SDRAM can be
        -- accessed from three channels (slave2 - slave4) the first one will be
        -- selected due to priority.
        wb_sim_read32(clk, wb_masters_tx(0), wb_masters_rx(0), x"8000_0000", x"0000_0002");

        -- Report successful test.
        REPORT "Test Master0 OK";
        tb_done0 <= '1';
        WAIT;
    END PROCESS master0;

    -- This is master1 with the second highest priority, writes are not checked
    -- but reads are expected to come from a specific slave id. Accesses are
    -- delayed by one clock! The below defined process for the master2 (with
    -- less priority) accessed the same slaves as this one, but one clock
    -- earlier. This causes reads from this master to be delayed, even though
    -- this master has higher priority. This is because the crossbar must not
    -- remove the granted connection from master2 while the transaction is live.
    master1 : PROCESS IS
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(clk);
        WAIT UNTIL rising_edge(clk); -- delay master by one clock

        -- Read from IMEM over slave1 channel. Even tough the IMEM can be
        -- accessed from two channels (slave0 and slave1) the first one will be
        -- selected. This is because the other masters did access the IMEM
        -- earlier and this one was delayed.
        wb_sim_read32(clk, wb_masters_tx(1), wb_masters_rx(1), x"0000_0000", x"0000_0000");
        -- Read from SDRAM over slave2 channel. Even tough the SDRAM can be
        -- accessed from three channels (slave2 - slave4) the first one will be
        -- selected due to priority (same as the read above)
        wb_sim_read32(clk, wb_masters_tx(1), wb_masters_rx(1), x"8000_0000", x"0000_0002");

        -- Report successful test.
        REPORT "Test Master1 OK";
        tb_done1 <= '1';
        WAIT;
    END PROCESS master1;

    -- This is master2 with the lowest priority, writes are not checked but
    -- reads are expected to come from a specific slave id. As this master reads
    -- one clock earlied than master1, he gets granted access to the IMEM or
    -- SDRAM even though the other master has the higher priority. This is
    -- because the crossbar must not take away the granted access while the
    -- master is sill using it, regardless of its priority.
    master2 : PROCESS IS
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(clk);

        -- Read from IMEM over slave1 channel. The IMEM is also accessed by the
        -- other two masters. As it only has two channels and the first one is
        -- already used by master0, this master read will read through the
        -- second channel. This read blocks master1 that will try to read the
        -- IMEM as well but one clock later.
        wb_sim_read32(clk, wb_masters_tx(2), wb_masters_rx(2), x"0000_0000", x"0000_0001");
        -- Read from SDRAM. Same as with the IMEM, second channel used and will
        -- block master1 to access.
        wb_sim_read32(clk, wb_masters_tx(2), wb_masters_rx(2), x"8000_0000", x"0000_0003");
        -- Read from an invalid address. Expect to be forwarded to "others"
        -- channel. This is hooked up to a constant error slave and we expect to
        -- fail. Read is right at the end of SDRAM size.
        wb_sim_read32(clk, wb_masters_tx(2), wb_masters_rx(2), x"8200_0000", x"dead_beef", true);

        -- Report successful test.
        REPORT "Test Master2 OK";
        tb_done2 <= '1';
        WAIT;
    END PROCESS master2;

    -- This is master3 and would have the lowest priority of all. But it only
    -- runs after the other masters have finished theirs tests. Its purpose it
    -- so check the address decoding. The two slaves have specific addresses and
    -- an associated address range that should work correctly, this is tested.
    master3 : PROCESS IS
    BEGIN
        -- Wait for test of other masters to finish.
        WAIT UNTIL tb_done0 = '1' AND tb_done1 = '1' AND tb_done2 = '1';

        -- Check IMEM address decoding from address 0x0000_0000, size 1 KB
        wb_sim_read32(clk, wb_masters_tx(3), wb_masters_rx(3), x"0000_0000", x"0000_0000"); -- start
        wb_sim_read32(clk, wb_masters_tx(3), wb_masters_rx(3), x"0000_03fc", x"0000_0000"); -- end
        wb_sim_read32(clk, wb_masters_tx(3), wb_masters_rx(3), x"0000_0400", x"dead_beef", true); -- end+1
        
        -- Check SDRAM address decoding from address 0x8000_0000, size 32 MB
        wb_sim_read32(clk, wb_masters_tx(3), wb_masters_rx(3), x"7fff_fffc", x"dead_beef", true); -- start-1
        wb_sim_read32(clk, wb_masters_tx(3), wb_masters_rx(3), x"8000_0000", x"0000_0002"); -- start
        wb_sim_read32(clk, wb_masters_tx(3), wb_masters_rx(3), x"81ff_fffc", x"0000_0002"); -- end
        wb_sim_read32(clk, wb_masters_tx(3), wb_masters_rx(3), x"8200_0000", x"dead_beef", true); -- end+1

        -- Report successful test.
        REPORT "Test Master3 OK";
        tb_done3 <= '1';
        WAIT;
    END PROCESS master3;

    -- Let each slave respond with an ack for one clock after is has seen a stb
    -- from a master. On read accesses it will return the id of the slave.
    dummy_slaves : PROCESS (clk, wb_slaves_rx, slave_delayed_stb) IS
    BEGIN
        -- respond with an ack one cycle after stb
        FOR s IN WB_N_SLAVES - 1 DOWNTO 0 LOOP
            IF rising_edge(clk) THEN
                slave_delayed_stb(s) <= wb_slaves_rx(s).stb;
            END IF;
            wb_slaves_tx(s).ack <= '1' WHEN (slave_delayed_stb(s) = '1' and wb_slaves_rx(s).stb = '1') ELSE
            '0';
            wb_slaves_tx(s).err <= '0'; -- never any error
            wb_slaves_tx(s).dat <= STD_ULOGIC_VECTOR(to_unsigned(s, WB_DATA_WIDTH)); -- slave number
        END LOOP;
    END PROCESS dummy_slaves;

END ARCHITECTURE simulation;
