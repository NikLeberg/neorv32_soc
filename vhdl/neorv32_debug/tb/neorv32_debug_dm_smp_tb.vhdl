-- =============================================================================
-- File:                    neorv32_debug_dm_smp_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  neorv32_debug_dm_smp_tb
--
-- Description:             Testbench for the custom SMP variant of neorv32
--                          debug module.
--
-- Changes:                 0.1, 2023-09-05, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

USE work.wb_pkg.ALL;

ENTITY neorv32_debug_dm_smp_tb IS
    -- Testbench needs no ports.
END ENTITY neorv32_debug_dm_smp_tb;

ARCHITECTURE simulation OF neorv32_debug_dm_smp_tb IS

    -- Signals for sequential DUTs.
    CONSTANT CLK_PERIOD : DELAY_LENGTH := 20 ns; -- 50 MHz
    SIGNAL clk : STD_LOGIC := '1';
    SIGNAL rstn : STD_LOGIC := '0';
    SIGNAL tb_done : STD_LOGIC := '0'; -- flag end of tests
    CONSTANT TIMEOUT : DELAY_LENGTH := 10 * CLK_PERIOD;
    CONSTANT TIMEOUT_BUSY : NATURAL := 1000; -- how long to wait for busy abstract
    CONSTANT TIMEOUT_REQ : NATURAL := 1000; -- how long to wait for halt/resume requests

    -- Signals for connecting to the DUT.
    CONSTANT NUM_HARTS : NATURAL := 4;
    SIGNAL dmi_req : dmi_req_t;
    SIGNAL dmi_rsp : dmi_rsp_t;
    SIGNAL bus_req : bus_req_t;
    SIGNAL bus_rsp : bus_rsp_t;
    SIGNAL dci_cpu_debug : STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0); -- CPU is in debug mode
    SIGNAL dci_ndmrstn : STD_ULOGIC;
    SIGNAL dci_halt_req : STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0);

    -- Extra signsl for connecting DUT to a CPU.
    SIGNAL wb_req : wb_req_arr_t(2 * NUM_HARTS - 1 DOWNTO 0);
    SIGNAL wb_resp : wb_resp_arr_t(2 * NUM_HARTS - 1 DOWNTO 0);
    SIGNAL wb_slv_req : wb_req_arr_t(1 DOWNTO 0);
    SIGNAL wb_slv_resp : wb_resp_arr_t(1 DOWNTO 0);
    SIGNAL wb_imem_portb_resp : wb_resp_sig_t; -- dummy
    CONSTANT WB_MEMORY_MAP : wb_map_t :=
    (
    (x"0000_0000", 1 * 1024), -- IMEM, 1 KB (port a)
    (base_io_dm_c, iodev_size_c) -- NEORV32 OCD, 256 B
    );
    -- CONSTANT wb_err_resp : wb_resp_sig_t := (ack => '0', err => '1', dat => (OTHERS => '0'));
    SIGNAL wb_err_resp : wb_resp_sig_t := (ack => '0', err => '1', dat => (OTHERS => '0'));
    -- CONSTANT wb_master_no_req : wb_req_sig_t := (cyc => '0', stb => '0', we => '0', sel => (OTHERS => '0'), adr => (OTHERS => '0'), dat => (OTHERS => '0'));
    SIGNAL wb_master_no_req : wb_req_sig_t := (cyc => '0', stb => '0', we => '0', sel => (OTHERS => '0'), adr => (OTHERS => '0'), dat => (OTHERS => '0'));

    -- available DMI registers --
    CONSTANT addr_data0_c : STD_ULOGIC_VECTOR(6 DOWNTO 0) := "000" & x"4";
    CONSTANT addr_dmcontrol_c : STD_ULOGIC_VECTOR(6 DOWNTO 0) := "001" & x"0";
    CONSTANT addr_dmstatus_c : STD_ULOGIC_VECTOR(6 DOWNTO 0) := "001" & x"1";
    CONSTANT addr_hartinfo_c : STD_ULOGIC_VECTOR(6 DOWNTO 0) := "001" & x"2";
    CONSTANT addr_abstractcs_c : STD_ULOGIC_VECTOR(6 DOWNTO 0) := "001" & x"6";
    CONSTANT addr_command_c : STD_ULOGIC_VECTOR(6 DOWNTO 0) := "001" & x"7";
    CONSTANT addr_abstractauto_c : STD_ULOGIC_VECTOR(6 DOWNTO 0) := "001" & x"8";
    CONSTANT addr_nextdm_c : STD_ULOGIC_VECTOR(6 DOWNTO 0) := "001" & x"d";
    CONSTANT addr_progbuf0_c : STD_ULOGIC_VECTOR(6 DOWNTO 0) := "010" & x"0";
    CONSTANT addr_progbuf1_c : STD_ULOGIC_VECTOR(6 DOWNTO 0) := "010" & x"1";
    CONSTANT addr_sbcs_c : STD_ULOGIC_VECTOR(6 DOWNTO 0) := "011" & x"8";
    CONSTANT addr_haltsum0_c : STD_ULOGIC_VECTOR(6 DOWNTO 0) := "100" & x"0";

BEGIN

    -- Clock that stops after all tests are done.
    clk <= '0' WHEN tb_done = '1' ELSE
        NOT clk AFTER 0.5 * CLK_PERIOD;

    -- Power on reset the DUT, lasts two clock cycles.
    rstn <= '0', '1' AFTER 2 * CLK_PERIOD;

    -- Instantiate the device under test.
    dut : ENTITY work.neorv32_debug_dm_smp
        GENERIC MAP(
            CPU_BASE_ADDR => base_io_dm_c,
            LEGACY_MODE   => false,    -- false = spec. v1.0, true = spec. v0.13
            NUM_HARTS     => NUM_HARTS -- number of implemented harts i.e. CPUs, 1 to 32
        )
        PORT MAP(
            -- global control --
            clk_i       => clk,           -- global clock line
            rstn_i      => rstn,          -- global reset line, low-active
            cpu_debug_i => dci_cpu_debug, -- CPU is in debug mode
            -- debug module interface (DMI) --
            dmi_req_i => dmi_req, -- request
            dmi_rsp_o => dmi_rsp, -- response
            -- CPU bus access --
            bus_req_i => bus_req, -- bus request
            bus_rsp_o => bus_rsp, -- bus response
            -- CPU control --
            cpu_ndmrstn_o  => dci_ndmrstn, -- soc reset (all harts)
            cpu_halt_req_o => dci_halt_req -- request hart to halt (enter debug mode)
        );

    -- DUT needs a CPU to properly work (i.e. run the program buffer)
    neorv32_cpu_smp_inst : ENTITY work.neorv32_cpu_smp
        GENERIC MAP(
            -- General --
            CLOCK_FREQUENCY   => 1 sec / CLK_PERIOD, -- clock frequency of clk_i in Hz
            NUM_HARTS         => NUM_HARTS,          -- number of implemented harts i.e. CPUs
            INT_BOOTLOADER_EN => false,              -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM
            -- On-Chip Debugger (OCD) --
            ON_CHIP_DEBUGGER_EN => true, -- implement on-chip debugger
            -- Internal Instruction Cache (iCACHE) --
            ICACHE_EN => true -- implement instruction cache
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk,  -- global clock, rising edge
            rstn_i => rstn, -- global reset, low-active, async
            -- Wishbone instruction bus interface(s), two per hart --
            wb_master_o => wb_req(2 * NUM_HARTS - 1 DOWNTO 0),  -- control and data from master to slave
            wb_master_i => wb_resp(2 * NUM_HARTS - 1 DOWNTO 0), -- status and data from slave to master
            -- CPU interrupts --
            mti_i => (OTHERS => '0'), -- risc-v machine timer interrupt
            msi_i => (OTHERS => '0'), -- risc-v machine software interrupt
            mei_i => (OTHERS => '0'), -- risc-v machine external interrupt
            -- debug core interface (DCI) --
            dci_ndmrstn_i   => dci_ndmrstn,  -- soc reset (all harts)
            dci_halt_req_i  => dci_halt_req, -- request hart to halt (enter debug mode)
            dci_cpu_debug_o => dci_cpu_debug -- cpu is in debug mode
        );

    -- The wishbone busses of the CPU need to be muxed.
    wb_crossbar_inst : ENTITY work.wb_crossbar_rr
        GENERIC MAP(
            -- General --
            N_MASTERS  => 2 * NUM_HARTS, -- number of connected masters
            N_SLAVES   => 2,             -- number of connected slaves
            MEMORY_MAP => WB_MEMORY_MAP  -- memory map of address space
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk,  -- global clock, rising edge
            rstn_i => rstn, -- global reset, low-active, asyn
            -- Wishbone master interface --
            wb_masters_i => wb_req,
            wb_masters_o => wb_resp,
            -- Wishbone slave interface(s) --
            wb_slaves_o => wb_slv_req,
            wb_slaves_i => wb_slv_resp,
            -- Other unmapped Wishbone slave interface(s) --
            wb_others_i => wb_err_resp
        );

    -- IMEM dual-port ROM --
    wb_imem_inst : ENTITY work.wb_imem
        GENERIC MAP(
            IMEM_SIZE => 1 * 1024 -- size of instruction memory in bytes
        )
        PORT MAP(
            -- Global control --
            clk_i  => clk,  -- global clock, rising edge
            rstn_i => rstn, -- global reset, low-active, asyn
            -- Wishbone slave interfaces --
            wb_slaves_i(0) => wb_slv_req(0), -- control and data from master to slave
            wb_slaves_i(1) => wb_master_no_req,
            wb_slaves_o(0) => wb_slv_resp(0), -- status and data from slave to master
            wb_slaves_o(1) => wb_imem_portb_resp
        );

    -- Map Wishbone signals to neorv32 internal bus of debug module.
    bus_req.we <= wb_slv_req(1).stb AND wb_slv_req(1).we;
    bus_req.re <= wb_slv_req(1).stb AND NOT wb_slv_req(1).we;
    bus_req.addr <= wb_slv_req(1).adr;
    bus_req.data <= wb_slv_req(1).dat;
    bus_req.ben <= wb_slv_req(1).sel;
    wb_slv_resp(1).dat <= bus_rsp.data;
    wb_slv_resp(1).ack <= bus_rsp.ack;
    wb_slv_resp(1).err <= bus_rsp.err;

    -- Actual testing process.
    test : PROCESS IS
        --
        -- read a dmi register
        PROCEDURE dmi_read(
            addr : STD_ULOGIC_VECTOR(6 DOWNTO 0) -- register to read
        ) IS BEGIN
            -- sync to rising edge of clock
            WAIT UNTIL rising_edge(clk);
            -- start the read
            dmi_req.op <= dmi_req_rd_c;
            dmi_req.addr <= addr;
            dmi_req.data <= (OTHERS => 'X');
            -- wait for ack
            WAIT UNTIL rising_edge(dmi_rsp.ack) FOR TIMEOUT;
            ASSERT dmi_rsp.ack = '1'
            REPORT "Read did not ack."
                SEVERITY failure;
            -- cleanup op
            dmi_req.op <= dmi_req_nop_c;
        END PROCEDURE dmi_read;
        --
        -- write a dmi register
        PROCEDURE dmi_write(
            addr : STD_ULOGIC_VECTOR(6 DOWNTO 0); -- register to write
            data : STD_ULOGIC_VECTOR(31 DOWNTO 0) -- data to write
        ) IS BEGIN
            -- sync to rising edge of clock
            WAIT UNTIL rising_edge(clk);
            -- start the write
            dmi_req.op <= dmi_req_wr_c;
            dmi_req.addr <= addr;
            dmi_req.data <= data;
            -- wait for ack
            WAIT UNTIL rising_edge(dmi_rsp.ack) FOR TIMEOUT;
            ASSERT dmi_rsp.ack = '1'
            REPORT "Write did not ack."
                SEVERITY failure;
            -- cleanup op
            dmi_req.op <= dmi_req_nop_c;
        END PROCEDURE dmi_write;
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(rstn);
        WAIT UNTIL rising_edge(clk);

        -- Examine DM and harts, loosely based on openocd implementation from:
        -- https://github.com/riscv/riscv-openocd/blob/riscv/src/target/riscv/riscv-013.c

        -- reset DM and enable
        dmi_write(addr_dmcontrol_c, x"0000_0000");
        dmi_write(addr_dmcontrol_c, x"0000_0001");
        dmi_read(addr_dmcontrol_c);
        ASSERT dmi_rsp.data(0) = '1'
        REPORT "DM did not become active."
            SEVERITY failure;
        -- check version = 3 = v1.0
        dmi_read(addr_dmstatus_c);
        ASSERT dmi_rsp.data(3 DOWNTO 0) = x"3"
        REPORT "Not supported Version."
            SEVERITY failure;
        -- determine hartsellen by writing hartsello, hartselhi and hasel
        dmi_write(addr_dmcontrol_c, x"07ff_ffc1");
        dmi_read(addr_dmcontrol_c);
        ASSERT UNSIGNED(dmi_rsp.data(25 DOWNTO 16)) = to_unsigned((2 ** log2(NUM_HARTS)) - 1, 10)
        REPORT "Incorrect hartsellen."
            SEVERITY failure;
        -- select hart 0
        dmi_write(addr_dmcontrol_c, x"0001_0001");
        -- check abstract data registers are accessible
        dmi_read(addr_abstractcs_c);
        ASSERT dmi_rsp.data(28 DOWNTO 24) = "00010"
        REPORT "progbufsize != 2."
            SEVERITY failure;
        ASSERT dmi_rsp.data(3 DOWNTO 0) = "0001"
        REPORT "datacount != 1."
            SEVERITY failure;

        -- enumerate harts
        FOR i IN 0 TO NUM_HARTS LOOP
            -- select hart i
            dmi_write(addr_dmcontrol_c, "000000" & STD_ULOGIC_VECTOR(to_unsigned(i, 10)) & x"0001");
            -- all but last+1 hart should be existant
            dmi_read(addr_dmstatus_c);
            IF i < NUM_HARTS THEN
                ASSERT dmi_rsp.data(15 DOWNTO 14) = "00"
                REPORT "Hart " & INTEGER'image(i) & " is nonexistant."
                    SEVERITY failure;
            ELSE
                ASSERT dmi_rsp.data(15 DOWNTO 14) /= "00"
                REPORT "Hart " & INTEGER'image(i) & " exists, but it should not!"
                    SEVERITY failure;
            END IF;
        END LOOP;

        -- examine all harts
        FOR i IN 0 TO NUM_HARTS - 1 LOOP
            -- select hart i
            dmi_write(addr_dmcontrol_c, "000000" & STD_ULOGIC_VECTOR(to_unsigned(i, 10)) & x"0001");
            -- check state of hart i
            dmi_read(addr_dmstatus_c);
            ASSERT dmi_rsp.data(19 DOWNTO 18) = "00"
            REPORT "Hart " & INTEGER'image(i) & " is in reset."
                SEVERITY failure;
            ASSERT dmi_rsp.data(13 DOWNTO 8) /= "000000"
            REPORT "Hart " & INTEGER'image(i) & " is neither unavailable, running nor halted."
                SEVERITY failure;
            -- request hart i to halt
            dmi_write(addr_dmcontrol_c, "100000" & STD_ULOGIC_VECTOR(to_unsigned(i, 10)) & x"0001");
            -- wait until hart i is halted
            FOR i IN 0 TO TIMEOUT_REQ LOOP
                dmi_read(addr_dmstatus_c);
                IF dmi_rsp.data(9 DOWNTO 8) /= "00" THEN
                    EXIT;
                END IF;
            END LOOP;
            ASSERT dmi_rsp.data(9) = '1'
            REPORT "Hart " & INTEGER'image(i) & " could not be halted [examine]!"
                SEVERITY failure;
            -- clear halt request
            dmi_write(addr_dmcontrol_c, "000000" & STD_ULOGIC_VECTOR(to_unsigned(i, 10)) & x"0001");
            -- do an abstract read of s0 of 64 bit width => should fail
            dmi_write(addr_command_c, x"00" & '0' & "011" & "0010" & x"1008");
            -- wait until idle
            FOR i IN 0 TO TIMEOUT_BUSY LOOP
                dmi_read(addr_abstractcs_c);
                IF dmi_rsp.data(12) = '0' THEN
                    EXIT;
                END IF;
            END LOOP;
            ASSERT dmi_rsp.data(12) = '0'
            REPORT "Busy trying to execute abstract command."
                SEVERITY failure;
            -- expect error (64 bit width not supported)
            ASSERT dmi_rsp.data(10 DOWNTO 8) = "010"
            REPORT "Abstract read of s0 with 64 bits should fail!"
                SEVERITY failure;
            -- reset error
            dmi_write(addr_abstractcs_c, x"0000_0700");
            -- check if error was actually reset
            dmi_read(addr_abstractcs_c);
            ASSERT dmi_rsp.data(10 DOWNTO 8) = "000"
            REPORT "Error in abstract command should have been reset to 0!"
                SEVERITY failure;
            -- do an abstract read of s0 of 32 bit width => should succeed
            dmi_write(addr_command_c, x"00" & '0' & "010" & "0010" & x"1008");
            -- wait until idle
            FOR i IN 0 TO TIMEOUT_BUSY LOOP
                dmi_read(addr_abstractcs_c);
                IF dmi_rsp.data(12) = '0' THEN
                    EXIT;
                END IF;
            END LOOP;
            ASSERT dmi_rsp.data(12) = '0'
            REPORT "Busy trying to execute abstract command."
                SEVERITY failure;
            -- expect success
            ASSERT dmi_rsp.data(10 DOWNTO 8) = "000"
            REPORT "Abstract read of s0 with 32 bits did fail."
                SEVERITY failure;
            -- read the data0 where the just transferred data from s0 is
            dmi_read(addr_data0_c);
            -- repeat abstract read for register s1
            dmi_write(addr_command_c, x"00" & '0' & "010" & "0010" & x"1009");
            FOR i IN 0 TO TIMEOUT_BUSY LOOP
                dmi_read(addr_abstractcs_c);
                IF dmi_rsp.data(12) = '0' THEN
                    EXIT;
                END IF;
            END LOOP;
            ASSERT dmi_rsp.data(12) = '0'
            REPORT "Busy trying to execute abstract command."
                SEVERITY failure;
            ASSERT dmi_rsp.data(10 DOWNTO 8) = "000"
            REPORT "Abstract read of s1 with 32 bits did fail."
                SEVERITY failure;
            dmi_read(addr_data0_c);
            -- read MISA csr through program buffer
            dmi_write(addr_progbuf0_c, x"30102473"); -- csrr
            dmi_write(addr_progbuf1_c, x"00100073"); -- ebreak
            dmi_write(addr_command_c, x"00" & '0' & "010" & "0100" & x"1000"); -- execute program
            FOR i IN 0 TO TIMEOUT_BUSY LOOP
                dmi_read(addr_abstractcs_c);
                IF dmi_rsp.data(12) = '0' THEN -- wait until idle
                    EXIT;
                END IF;
            END LOOP;
            ASSERT dmi_rsp.data(12) = '0'
            REPORT "Busy trying to execute abstract command."
                SEVERITY failure;
            ASSERT dmi_rsp.data(10 DOWNTO 8) = "000"
            REPORT "Exec of program buffer failed."
                SEVERITY failure;
            dmi_write(addr_command_c, x"00" & '0' & "010" & "0010" & x"1008"); -- read s0
            FOR i IN 0 TO TIMEOUT_BUSY LOOP
                dmi_read(addr_abstractcs_c);
                IF dmi_rsp.data(12) = '0' THEN -- wait until idle
                    EXIT;
                END IF;
            END LOOP;
            ASSERT dmi_rsp.data(12) = '0'
            REPORT "Busy trying to execute abstract command."
                SEVERITY failure;
            ASSERT dmi_rsp.data(10 DOWNTO 8) = "000"
            REPORT "Abstract read of s0 with 32 bits did fail."
                SEVERITY failure;
            dmi_read(addr_data0_c); -- read result (MISA csr) from data0
            ASSERT dmi_rsp.data = x"40801101"
            REPORT "MISA of hart " & INTEGER'image(i) & " was expected to be " &
                "0x40801101 (RV32AIMX) and not " & to_hstring(dmi_rsp.data) & "."
                SEVERITY failure;
            -- request hart i to resume
            dmi_write(addr_dmcontrol_c, "010000" & STD_ULOGIC_VECTOR(to_unsigned(i, 10)) & x"0001");
            -- wait until hart i is resumed
            FOR i IN 0 TO TIMEOUT_REQ LOOP
                dmi_read(addr_dmstatus_c);
                IF dmi_rsp.data(17 DOWNTO 16) /= "00" THEN
                    EXIT;
                END IF;
            END LOOP;
            ASSERT dmi_rsp.data(17) = '1'
            REPORT "Hart " & INTEGER'image(i) & " could not be resumed [examine]!"
                SEVERITY failure;
            -- clear resume request
            dmi_write(addr_dmcontrol_c, "000000" & STD_ULOGIC_VECTOR(to_unsigned(i, 10)) & x"0001");
        END LOOP;

        -- halt all harts again
        FOR i IN 0 TO NUM_HARTS - 1 LOOP
            -- select hart i
            dmi_write(addr_dmcontrol_c, "000000" & STD_ULOGIC_VECTOR(to_unsigned(i, 10)) & x"0001");
            -- request hart i to halt
            dmi_write(addr_dmcontrol_c, "100000" & STD_ULOGIC_VECTOR(to_unsigned(i, 10)) & x"0001");
            -- wait until hart i is halted
            FOR i IN 0 TO TIMEOUT_REQ LOOP
                dmi_read(addr_dmstatus_c);
                IF dmi_rsp.data(9 DOWNTO 8) /= "00" THEN
                    EXIT;
                END IF;
            END LOOP;
            ASSERT dmi_rsp.data(9) = '1'
            REPORT "Hart " & INTEGER'image(i) & " could not be halted [all halt]!"
                SEVERITY failure;
            -- clear halt request
            dmi_write(addr_dmcontrol_c, "000000" & STD_ULOGIC_VECTOR(to_unsigned(i, 10)) & x"0001");
        END LOOP;

        -- resume all harts
        FOR i IN 0 TO NUM_HARTS - 1 LOOP
            -- select hart i
            dmi_write(addr_dmcontrol_c, "000000" & STD_ULOGIC_VECTOR(to_unsigned(i, 10)) & x"0001");
            -- request hart i to resume
            dmi_write(addr_dmcontrol_c, "010000" & STD_ULOGIC_VECTOR(to_unsigned(i, 10)) & x"0001");
            -- wait until hart i is resumed
            FOR i IN 0 TO TIMEOUT_REQ LOOP
                dmi_read(addr_dmstatus_c);
                IF dmi_rsp.data(17 DOWNTO 16) /= "00" THEN
                    EXIT;
                END IF;
            END LOOP;
            ASSERT dmi_rsp.data(17) = '1'
            REPORT "Hart " & INTEGER'image(i) & " could not be resumed!"
                SEVERITY failure;
            -- clear resume request
            dmi_write(addr_dmcontrol_c, "000000" & STD_ULOGIC_VECTOR(to_unsigned(i, 10)) & x"0001");
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        tb_done <= '1';
        WAIT;
    END PROCESS test;

END ARCHITECTURE simulation;
