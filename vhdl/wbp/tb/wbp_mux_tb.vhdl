-- =============================================================================
-- File:                    wbp_mux_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  wbp_mux_tb
--
-- Description:             Testbench for the one to many interconnect.
--
-- Changes:                 0.1, 2024-08-25, leuen4
--                              initial version
--                          0.2, 2024-10-08, leuen4
--                              fix too early de-assertion of address
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.wbp_pkg.ALL;

ENTITY wbp_mux_tb IS
    -- Testbench needs no ports.
END ENTITY wbp_mux_tb;

ARCHITECTURE simulation OF wbp_mux_tb IS

    -- Signals for sequential DUTs.
    CONSTANT CLK_PERIOD : DELAY_LENGTH := 20 ns; -- 50 MHz
    SIGNAL clk : STD_LOGIC := '1';
    SIGNAL rstn : STD_LOGIC := '0';
    SIGNAL tb_done : STD_LOGIC := '0'; -- flag end of tests

    -- Signals for connecting to the DUT.
    CONSTANT N_SLAVES : NATURAL := 3;
    CONSTANT MEMORY_MAP : wbp_map_t :=
    (
    (x"0000_0000", 1 * 1024), -- IMEM, 1 KB
    (x"8000_0000", 32 * 1024 * 1024), -- SDRAM, 32 MB
    (x"f000_0000", 64) -- IO, 64 B
    );
    SIGNAL wbp_master_mosi : wbp_mosi_sig_t := (
        cyc => '0', stb => '0', adr => (OTHERS => '0'), sel => (OTHERS => '0'), we => '0', dat => (OTHERS => '0')
    );
    SIGNAL wbp_master_miso : wbp_miso_sig_t;
    SIGNAL wbp_slaves_mosi : wbp_mosi_arr_t(N_SLAVES - 1 DOWNTO 0);
    SIGNAL wbp_slaves_miso : wbp_miso_arr_t(N_SLAVES - 1 DOWNTO 0) := (
        OTHERS => (stall => '0', ack => '0', err => '0', dat => (OTHERS => '0'))
    );

    -- Maximum delay for bus responses.
    CONSTANT MAX_DELAY: DELAY_LENGTH := 10 * CLK_PERIOD;

    -- Delayed and gated ack of dummy slaves.
    SIGNAL dummy_slaves_ack : STD_LOGIC_VECTOR(N_SLAVES - 1 downto 0) := (OTHERS => '0');

BEGIN
    -- Instantiate the device under test.
    dut : entity work.wbp_mux
    GENERIC MAP(
        -- General --
        N_SLAVES=>N_SLAVES,
        MEMORY_MAP=>MEMORY_MAP
    )
    PORT MAP(
        -- Wishbone master interface(s) --
        wbp_master_mosi => wbp_master_mosi,
        wbp_master_miso => wbp_master_miso,
        -- Wishbone slave interface(s) --
        wbp_slaves_mosi => wbp_slaves_mosi,
        wbp_slaves_miso => wbp_slaves_miso
    );

    -- Clock that stops after all tests are done.
    clk <= '0' WHEN tb_done = '1' ELSE
        NOT clk AFTER 0.5 * CLK_PERIOD;

    -- Power on reset the DUT, lasts two clock cycles.
    rstn <= '0', '1' AFTER 2 * CLK_PERIOD;

    test : PROCESS IS
        procedure sim_read (
            signal clk : in std_ulogic;
            signal master_mosi : out wbp_mosi_sig_t;
            signal master_miso : in wbp_miso_sig_t;
            constant address : STD_ULOGIC_VECTOR(WBP_ADDRESS_WIDTH - 1 DOWNTO 0);
            constant data : STD_ULOGIC_VECTOR(WBP_DATA_WIDTH - 1 DOWNTO 0)
        ) is
        begin
            master_mosi.adr <= address;
            master_mosi.dat <= (others => 'X');
            master_mosi.we <= '0';
            master_mosi.sel <= (others => '1');
            master_mosi.stb <= '1';
            master_mosi.cyc <= '1';
        
            WAIT UNTIL rising_edge(clk) AND master_miso.stall = '0' FOR MAX_DELAY;
            assert master_miso.stall = '0' report "slave did not deassert stall" severity failure;

            master_mosi.dat <= (others => '0');
            master_mosi.stb <= '0';

            for i in 1 to MAX_DELAY / CLK_PERIOD loop
                if master_miso.ack = '1' OR master_miso.err = '1' then
                    exit;
                end if;
                WAIT UNTIL rising_edge(clk);
            end loop;
            assert master_miso.err = '0' report "slave did respond with err" severity failure;
            assert master_miso.ack = '1' report "slave did not ack" severity failure;
            ASSERT master_miso.dat = data report "read data invalid" severity failure;

            master_mosi.cyc <= '0';
            master_mosi.adr <= (others => '0');
            master_mosi.we <= '0';
            master_mosi.sel <= (others => '0');

            WAIT UNTIL rising_edge(clk);
        end procedure sim_read;
        
        procedure sim_read_err (
            signal clk : in std_ulogic;
            signal master_mosi : out wbp_mosi_sig_t;
            signal master_miso : in wbp_miso_sig_t;
            constant address : STD_ULOGIC_VECTOR(WBP_ADDRESS_WIDTH - 1 DOWNTO 0)
        ) is
        begin
            master_mosi.adr <= address;
            master_mosi.dat <= (others => 'X');
            master_mosi.we <= '0';
            master_mosi.sel <= (others => '1');
            master_mosi.stb <= '1';
            master_mosi.cyc <= '1';
        
            WAIT UNTIL rising_edge(clk) AND master_miso.stall = '0' FOR MAX_DELAY;
            assert master_miso.stall = '0' report "slave did not deassert stall" severity failure;

            master_mosi.dat <= (others => '0');
            master_mosi.stb <= '0';

            for i in 1 to MAX_DELAY / CLK_PERIOD loop
                if master_miso.ack = '1' OR master_miso.err = '1' then
                    exit;
                end if;
                WAIT UNTIL rising_edge(clk);
            end loop;
            assert master_miso.err = '1' report "slave did NOT respond with err" severity failure;

            master_mosi.cyc <= '0';
            master_mosi.adr <= (others => '0');
            master_mosi.we <= '0';
            master_mosi.sel <= (others => '0');

            WAIT UNTIL rising_edge(clk);
        end procedure sim_read_err;
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(clk);

        -- Try to read each slave id.
        -- IMEM = 0
        sim_read(clk, wbp_master_mosi, wbp_master_miso, x"0000_0000", x"0000_0000");
        -- SDRAM = 1
        sim_read(clk, wbp_master_mosi, wbp_master_miso, x"8000_0000", x"0000_0001");
        -- IO = 2
        sim_read(clk, wbp_master_mosi, wbp_master_miso, x"f000_0000", x"0000_0002");

        -- Try to read address ranges of each slave.
        -- IMEM = 1 KB
        sim_read(clk, wbp_master_mosi, wbp_master_miso, x"0000_0000", x"0000_0000");
        sim_read(clk, wbp_master_mosi, wbp_master_miso, x"0000_03fc", x"0000_0000");
        sim_read_err(clk, wbp_master_mosi, wbp_master_miso, x"0000_0400");
        -- SDRAM = 32 MB
        sim_read_err(clk, wbp_master_mosi, wbp_master_miso, x"7fff_fffc");
        sim_read(clk, wbp_master_mosi, wbp_master_miso, x"8000_0000", x"0000_0001");
        sim_read(clk, wbp_master_mosi, wbp_master_miso, x"81ff_fffc", x"0000_0001");
        sim_read_err(clk, wbp_master_mosi, wbp_master_miso, x"8200_0000");
        -- IO = 64 B
        sim_read_err(clk, wbp_master_mosi, wbp_master_miso, x"efff_fffc");
        sim_read(clk, wbp_master_mosi, wbp_master_miso, x"f000_0000", x"0000_0002");
        sim_read(clk, wbp_master_mosi, wbp_master_miso, x"f000_003c", x"0000_0002");
        sim_read_err(clk, wbp_master_mosi, wbp_master_miso, x"f000_0040");

        -- Report successful test.
        REPORT "Test OK";
        tb_done <= '1';
        WAIT;
    END PROCESS test;

    -- Let each slave respond with an ack for one clock after is has seen a stb
    -- from a master. On read accesses it will return the id of the slave.
    dummy_slaves_gen : for s in 0 to N_SLAVES-1 generate
        dummy_slaves_ack(s) <= wbp_slaves_mosi(s).stb when rising_edge(clk);
        wbp_slaves_miso(s).ack <= dummy_slaves_ack(s) AND wbp_slaves_mosi(s).cyc;
        wbp_slaves_miso(s).stall <= '0'; -- never stalled
        wbp_slaves_miso(s).err <= '0'; -- never any error
        wbp_slaves_miso(s).dat <= STD_ULOGIC_VECTOR(to_unsigned(s, WBP_DATA_WIDTH)) WHEN wbp_slaves_miso(s).ack = '1' ELSE (OTHERS => '0'); -- slave number
    end generate dummy_slaves_gen;

END ARCHITECTURE simulation;
