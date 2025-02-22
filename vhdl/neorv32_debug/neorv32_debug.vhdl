-- =============================================================================
-- File:                    neorv32_debug.vhdl
--
-- Entity:                  neorv32_debug
--
-- Description:             On-Chip Debugger Complex of NEORV32 SoC. Simply
--                          groups the debug Module (DM) and debug transport
--                          module (DTM) and gives it a wishbone wrapper. To
--                          support multiple harts in a SMP configuration it
--                          also uses the custom implementations of DM and DTM.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.2
--
-- Changes:                 0.1, 2023-08-27, NikLeberg
--                              initial version
--                          0.2, 2024-09-14, NikLeberg
--                              update to pipelined wishbone variant
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

USE work.wbp_pkg.ALL;

ENTITY neorv32_debug IS
    GENERIC (
        NUM_HARTS : NATURAL;                       -- number of implemented harts i.e. CPUs
        BASE_ADDR : STD_ULOGIC_VECTOR(31 DOWNTO 0) -- base address of this debug module
    );
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, async

        -- jtag connection --
        jtag_tck_i : IN STD_ULOGIC;
        jtag_tdi_i : IN STD_ULOGIC;
        jtag_tdo_o : OUT STD_ULOGIC;
        jtag_tms_i : IN STD_ULOGIC;

        -- debug core interface (DCI) --
        dci_ndmrstn_o   : OUT STD_ULOGIC;                                -- soc reset (all harts)
        dci_halt_req_o  : OUT STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0); -- request hart to halt (enter debug mode)
        dci_cpu_debug_i : IN STD_ULOGIC_VECTOR(NUM_HARTS - 1 DOWNTO 0);  -- cpu is in debug mode

        -- Wishbone slave interface --
        wbp_mosi : IN wbp_mosi_sig_t; -- control and data from master to slave
        wbp_miso : OUT wbp_miso_sig_t -- status and data from slave to master
    );
END ENTITY neorv32_debug;

ARCHITECTURE no_target_specific OF neorv32_debug IS

    -- Signals of the neorv32 cpu internal bus.
    SIGNAL req : bus_req_t;
    SIGNAL rsp : bus_rsp_t;

    -- debug module interface (DMI) --
    SIGNAL dmi_req : dmi_req_t;
    SIGNAL dmi_rsp : dmi_rsp_t;

BEGIN

    -- Map Wishbone signals to neorv32 internal bus.
    req.stb <= wbp_mosi.stb;
    req.rw <= wbp_mosi.we;
    req.addr <= wbp_mosi.adr;
    req.data <= wbp_mosi.dat;
    req.ben <= wbp_mosi.sel;
    wbp_miso.dat <= rsp.data;
    wbp_miso.ack <= rsp.ack;
    wbp_miso.err <= rsp.err;
    wbp_miso.stall <= '0';

    -- **************************************************************************************************************************
    -- On-Chip Debugger Complex
    -- **************************************************************************************************************************

    -- On-Chip Debugger - Debug Transport Module (DTM) ----------------------------------------
    -- -------------------------------------------------------------------------------------------
    neorv32_debug_dtm_inst : ENTITY neorv32.neorv32_debug_dtm
        GENERIC MAP(
            IDCODE_VERSION => (OTHERS => '0'),
            IDCODE_PARTID => (OTHERS => '0'),
            IDCODE_MANID => (OTHERS => '0')
        )
        PORT MAP(
            -- global control --
            clk_i  => clk_i,
            rstn_i => rstn_i,
            -- jtag connection --
            jtag_tck_i => jtag_tck_i,
            jtag_tdi_i => jtag_tdi_i,
            jtag_tdo_o => jtag_tdo_o,
            jtag_tms_i => jtag_tms_i,
            -- debug module interface (DMI) --
            dmi_req_o => dmi_req,
            dmi_rsp_i => dmi_rsp
        );

    -- On-Chip Debugger - Debug Module (DM) ---------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    neorv32_debug_dm_inst : ENTITY work.neorv32_debug_dm_smp
        GENERIC MAP(
            CPU_BASE_ADDR => BASE_ADDR,
            LEGACY_MODE   => false,
            NUM_HARTS     => NUM_HARTS
        )
        PORT MAP(
            -- global control --
            clk_i       => clk_i,
            rstn_i      => rstn_i,
            cpu_debug_i => dci_cpu_debug_i,
            -- debug module interface (DMI) --
            dmi_req_i => dmi_req,
            dmi_rsp_o => dmi_rsp,
            -- CPU bus access --
            bus_req_i => req,
            bus_rsp_o => rsp,
            -- CPU control --
            cpu_ndmrstn_o  => dci_ndmrstn_o,
            cpu_halt_req_o => dci_halt_req_o
        );

END ARCHITECTURE no_target_specific;
