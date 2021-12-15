-- =============================================================================
-- File:                    example_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--                          Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  example_tb
--
-- Description:             Template file for vhdl entity testbench. Here should
--                          be described how and what will be tested. Note that
--                          the testbench is free to use non synthesizable
--                          features like wait and finish.
--
-- Changes:                 0.1, 2021-12-10, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY example_tb IS
    -- testbench needs no ports
END ENTITY example_tb;

ARCHITECTURE simulation OF example_tb IS
    -- component definition for device under test
    COMPONENT example
        PORT (
            a : IN STD_LOGIC;
            b : IN STD_LOGIC;
            y : OUT STD_LOGIC
        );
    END COMPONENT example;
    -- signals for connecting to the DUT
    SIGNAL s_a : STD_LOGIC;
    SIGNAL s_b : STD_LOGIC;
    SIGNAL s_y : STD_LOGIC;
BEGIN
    -- instantiate the device under test
    dut : example
    PORT MAP(
        a => s_a,
        b => s_b,
        y => s_y
    );

    -- =========================================================================
    -- Purpose: Run different test vectors agains the DUT and validate output.
    -- Type:    combinational, non-synthesizable
    -- Inputs:  s_y
    -- Outputs: s_a, s_b
    -- =========================================================================
    test : PROCESS IS
    BEGIN
        -- 1 AND 1 = 1
        s_a <= '1';
        s_b <= '1';
        WAIT FOR 10 ns;
        ASSERT s_y = '1' REPORT "1 AND 1 should equal 1." SEVERITY failure;

        -- 1 AND 0 = 0
        s_a <= '1';
        s_b <= '0';
        WAIT FOR 10 ns;
        ASSERT s_y = '0' REPORT "1 AND 0 should equal 0." SEVERITY failure;

        -- 0 AND 1 = 0
        s_a <= '0';
        s_b <= '1';
        WAIT FOR 10 ns;
        ASSERT s_y = '0' REPORT "0 AND 1 should equal 0." SEVERITY failure;

        -- 0 AND 0 = 0
        s_a <= '0';
        s_b <= '0';
        WAIT FOR 10 ns;
        ASSERT s_y = '0' REPORT "0 AND 0 should equal 0." SEVERITY failure;

        -- report successful test
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
