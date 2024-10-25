-- =============================================================================
-- File:                    wb_remap_tb.vhdl
--
-- Entity:                  wb_remap_tb
--
-- Description:             Testbench for the address remapper.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.1
--
-- Changes:                 0.1, 2023-09-25, NikLeberg
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.wb_pkg.ALL;

ENTITY wb_remap_tb IS
    -- Testbench needs no ports.
END ENTITY wb_remap_tb;

ARCHITECTURE simulation OF wb_remap_tb IS

    -- Signals for connecting to the DUT.
    CONSTANT WB_MEMORY_MAP_FROM : wb_map_t :=
    (
    (x"0000_0000", 1),
    (x"2000_0000", 1024),
    (x"4000_0000", 1024 * 1024)
    );
    CONSTANT WB_MEMORY_MAP_TO : wb_map_t :=
    (
    (x"aeae_aeae", 1),
    (x"8000_0000", 1024),
    (x"a000_0000", 1024 * 1024)
    );
    SIGNAL wb_master_original : wb_req_sig_t;
    SIGNAL wb_master_remapped : wb_req_sig_t;

BEGIN
    -- Instantiate the device under test.
    dut : ENTITY work.wb_remap
        GENERIC MAP(
            MEMORY_MAP_FROM => WB_MEMORY_MAP_FROM, -- from what address
            MEMORY_MAP_TO   => WB_MEMORY_MAP_TO    -- to what address
        )
        PORT MAP(
            -- Wishbone master interface --
            wb_master_i => wb_master_original, -- original request
            wb_master_o => wb_master_remapped  -- remapped request
        );

    test : PROCESS IS
        -- Procedure that generates stimuli for the given values. Response from
        -- DUT is checked for correctness.
        PROCEDURE check (
            CONSTANT original : STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0); -- original requested address
            CONSTANT remapped : STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0)  -- expected remapped address
        ) IS
        BEGIN
            wb_master_original.adr <= original;
            WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
            ASSERT wb_master_remapped.adr = remapped
            REPORT "Address was not remapped as expected."
                SEVERITY failure;
        END PROCEDURE check;
    BEGIN
        -- Check the start and end of each configured remapped address.

        -- Map x"0000_0000" to x"aeae_aeae" for 1 byte.
        check(x"0000_0000", x"aeae_aeae"); -- start & end
        check(x"0000_0001", x"0000_0001"); -- end + 1

        -- Map x"2000_0000" to x"8000_0000" for 1024 bytes.
        check(x"1fff_ffff", x"1fff_ffff"); -- start - 1
        check(x"2000_0000", x"8000_0000"); -- start
        check(x"2000_03ff", x"8000_03ff"); -- end
        check(x"2000_0400", x"2000_0400"); -- end + 1

        -- Map x"4000_0000" to x"a000_0000" for 1024 kilobytes.
        check(x"3fff_ffff", x"3fff_ffff"); -- start - 1
        check(x"4000_0000", x"a000_0000"); -- start
        check(x"400f_ffff", x"a00f_ffff"); -- end
        check(x"4010_0000", x"4010_0000"); -- end + 1

        -- Report successful test.
        REPORT "Test OK";
        WAIT;
    END PROCESS test;

END ARCHITECTURE simulation;
