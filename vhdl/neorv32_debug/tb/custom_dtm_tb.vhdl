-- =============================================================================
-- File:                    neorv32_debug_dtm_tb.vhdl
--
-- Entity:                  neorv32_debug_dtm_tb
--
-- Description:             Testbench for the Intel specific architecture
--                          implementation of the neorv32_debug_dtm entity.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.1
--
-- Changes:                 0.1, 2022-04-29, NikLeberg
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY neorv32_debug_dtm_tb IS
    -- Testbench needs no ports.
END ENTITY neorv32_debug_dtm_tb;

ARCHITECTURE simulation OF neorv32_debug_dtm_tb IS
    -- Component definition for device under test.
    COMPONENT custom_dtm IS
        GENERIC (
            IDCODE_VERSION : STD_ULOGIC_VECTOR(03 DOWNTO 0); -- version
            IDCODE_PARTID  : STD_ULOGIC_VECTOR(15 DOWNTO 0); -- part number
            IDCODE_MANID   : STD_ULOGIC_VECTOR(10 DOWNTO 0)  -- manufacturer id
        );
        PORT (
            -- global control --
            clk_i  : IN STD_ULOGIC; -- global clock line
            rstn_i : IN STD_ULOGIC; -- global reset line, low-active
            -- debug module interface (DMI) --
            dmi_req_valid_o   : OUT STD_ULOGIC;
            dmi_req_ready_i   : IN STD_ULOGIC; -- DMI is allowed to make new requests when set
            dmi_req_address_o : OUT STD_ULOGIC_VECTOR(05 DOWNTO 0);
            dmi_req_data_o    : OUT STD_ULOGIC_VECTOR(31 DOWNTO 0);
            dmi_req_op_o      : OUT STD_ULOGIC_VECTOR(01 DOWNTO 0);
            dmi_rsp_valid_i   : IN STD_ULOGIC;  -- response valid when set
            dmi_rsp_ready_o   : OUT STD_ULOGIC; -- ready to receive response
            dmi_rsp_data_i    : IN STD_ULOGIC_VECTOR(31 DOWNTO 0);
            dmi_rsp_op_i      : IN STD_ULOGIC_VECTOR(01 DOWNTO 0);
            -- simulated JTAG interface --
            ir_in      : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            ir_out     : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
            tck        : IN STD_LOGIC;
            tdi        : IN STD_LOGIC;
            tdo        : OUT STD_LOGIC;
            tms        : IN STD_LOGIC;
            dr_capture : IN STD_ULOGIC;
            ir_capture : IN STD_ULOGIC;
            dr_shift   : IN STD_ULOGIC;
            dr_update  : IN STD_ULOGIC;
            ir_update  : IN STD_ULOGIC
        );
    END COMPONENT custom_dtm;

    -- Signals for sequential DUTs.
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_tck : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';

    -- Signals for connecting to the DUT.

    TYPE dmi_req_t IS RECORD
        valid, ready : STD_ULOGIC;
        address : STD_ULOGIC_VECTOR(5 DOWNTO 0);
        data : STD_ULOGIC_VECTOR(31 DOWNTO 0);
        op : STD_ULOGIC_VECTOR(1 DOWNTO 0);
    END RECORD;
    SIGNAL dmi_req : dmi_req_t;

    TYPE dmi_rsp_t IS RECORD
        valid, ready : STD_ULOGIC;
        data : STD_ULOGIC_VECTOR(31 DOWNTO 0);
        op : STD_ULOGIC_VECTOR(1 DOWNTO 0);
    END RECORD;
    SIGNAL dmi_rsp : dmi_rsp_t;

    TYPE jtag_t IS RECORD
        ir_in : STD_LOGIC_VECTOR(4 DOWNTO 0);
        ir_out : STD_LOGIC_VECTOR(4 DOWNTO 0);
        tdi : STD_LOGIC;
        tdo : STD_LOGIC;
        tms : STD_LOGIC;
        dr_capture : STD_ULOGIC;
        ir_capture : STD_ULOGIC;
        dr_shift : STD_ULOGIC;
        dr_update : STD_ULOGIC;
        ir_update : STD_ULOGIC;
    END RECORD;
    SIGNAL jtag : jtag_t := (
        ir_in => "XXXXX",
        ir_out => "XXXXX",
        tdi => '0',
        tms => '0',
        tdo => 'X',
        dr_capture => '0',
        ir_capture => '0',
        dr_shift => '0',
        dr_update => '0',
        ir_update => '0');
BEGIN
    -- Instantiate the device under test.
    dut : custom_dtm
    GENERIC MAP(
        IDCODE_VERSION => "0000",
        IDCODE_PARTID  => x"5555",
        IDCODE_MANID   => "00000000000"
    )
    PORT MAP(
        clk_i             => s_clock,
        rstn_i            => s_n_reset,
        dmi_req_valid_o   => dmi_req.valid,
        dmi_req_ready_i   => dmi_req.ready,
        dmi_req_address_o => dmi_req.address,
        dmi_req_data_o    => dmi_req.data,
        dmi_req_op_o      => dmi_req.op,
        dmi_rsp_valid_i   => dmi_rsp.valid,
        dmi_rsp_ready_o   => dmi_rsp.ready,
        dmi_rsp_data_i    => dmi_rsp.data,
        dmi_rsp_op_i      => dmi_rsp.op,
        ir_in             => jtag.ir_in,
        ir_out            => jtag.ir_out,
        tck               => s_tck,
        tdi               => jtag.tdi,
        tdo               => jtag.tdo,
        tms               => jtag.tms,
        dr_capture        => jtag.dr_capture,
        ir_capture        => jtag.ir_capture,
        dr_shift          => jtag.dr_shift,
        dr_update         => jtag.dr_update,
        ir_update         => jtag.ir_update
    );

    -- Clock with 50 MHz.
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 10 ns;

    -- Clock with 10 MHz.
    s_tck <= '0' WHEN s_done = '1' ELSE
        NOT s_tck AFTER 50 ns;

    -- Power on reset the DUT, lasts two clock cycles.
    s_n_reset <= '0', '1' AFTER 40 ns;

    -- dmi test --
    dmi_rsp.valid <= '1';
    dmi_req.ready <= '1';
    dmi_rsp.op <= dmi_req.op;
    dmi_rsp.data <= dmi_req.data;

    test : PROCESS IS
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(s_clock);
        WAIT UNTIL rising_edge(s_tck);

        -- read idcode
        jtag.ir_capture <= '1';
        jtag.tdi <= 'X';
        WAIT UNTIL rising_edge(s_tck);
        jtag.ir_capture <= '0';

        jtag.ir_in <= "00001";
        jtag.ir_update <= '1';
        WAIT UNTIL rising_edge(s_tck);
        jtag.ir_update <= '0';
        jtag.ir_in <= "XXXXX";

        jtag.dr_capture <= '1';
        WAIT UNTIL rising_edge(s_tck);
        jtag.dr_capture <= '0';

        jtag.dr_shift <= '1';
        WAIT UNTIL rising_edge(s_tck);

        FOR i IN 0 TO 30 LOOP
            WAIT UNTIL rising_edge(s_tck);
        END LOOP;
        jtag.dr_shift <= '0';
        WAIT UNTIL rising_edge(s_tck);

        jtag.dr_update <= '1';
        WAIT UNTIL rising_edge(s_tck);
        jtag.dr_update <= '0';

        -- write dmi
        jtag.ir_capture <= '1';
        WAIT UNTIL rising_edge(s_tck);
        jtag.ir_capture <= '0';

        jtag.ir_in <= "10001";
        jtag.ir_update <= '1';
        WAIT UNTIL rising_edge(s_tck);
        jtag.ir_update <= '0';
        jtag.ir_in <= "XXXXX";

        jtag.dr_capture <= '1';
        WAIT UNTIL rising_edge(s_tck);
        jtag.dr_capture <= '0';

        jtag.dr_shift <= '1';
        jtag.tdi <= '0';
        WAIT UNTIL rising_edge(s_tck);
        WAIT UNTIL rising_edge(s_tck);
        jtag.tdi <= '1';

        FOR i IN 0 TO 38 LOOP
            WAIT UNTIL rising_edge(s_tck);
        END LOOP;
        jtag.dr_shift <= '0';
        jtag.tdi <= 'X';
        WAIT UNTIL rising_edge(s_tck);

        jtag.dr_update <= '1';
        WAIT UNTIL rising_edge(s_tck);
        jtag.dr_update <= '0';

        -- DMI FSM test --
        FOR i IN 0 TO 39 LOOP
            WAIT UNTIL rising_edge(s_tck);
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
