-- =============================================================================
-- File:                    arb_round_robin_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  arb_round_robin_tb
--
-- Description:             Testbench for arb_round_robin entity. Checks if the
--                          round-robin arbitration i.e. priority given to the
--                          requests is correct.
--
-- Changes:                 0.1, 2023-09-10, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY arb_round_robin_tb IS
    -- Testbench needs no ports.
END ENTITY arb_round_robin_tb;

ARCHITECTURE simulation OF arb_round_robin_tb IS
    -- Signals for connecting to the DUT.
    CONSTANT NUM : NATURAL := 3;
    SIGNAL req, prev, ack : STD_ULOGIC_VECTOR(NUM - 1 DOWNTO 0);
BEGIN
    -- Instantiate the device under test.
    dut : ENTITY work.arb_round_robin
        GENERIC MAP(
            NUM => NUM -- how many requests to arbitrate
        )
        PORT MAP(
            req  => req,  -- requests
            prev => prev, -- to whom was last granted access
            ack  => ack   -- acknowledge of request
        );

    test : PROCESS IS
        -- Procedure that generates stimuli for the given values. Response from
        -- DUT is checked for correctness.
        PROCEDURE check (
            CONSTANT ass_req  : STD_ULOGIC_VECTOR(NUM - 1 DOWNTO 0); -- request
            CONSTANT ass_prev : STD_ULOGIC_VECTOR(NUM - 1 DOWNTO 0); -- previous granted request
            CONSTANT exp_ack  : STD_ULOGIC_VECTOR(NUM - 1 DOWNTO 0)  -- expected ack
        ) IS
        BEGIN
            req <= ass_req;
            prev <= ass_prev;
            WAIT FOR 1 ns; -- A bit of time for combinational logic to settle.
            ASSERT exp_ack = ack
            REPORT "Expected ack for " & INTEGER'image(to_integer(UNSIGNED(exp_ack))) &
            " but got ack for " & INTEGER'image(to_integer(UNSIGNED(ack))) & "."
            SEVERITY failure;
        END PROCEDURE check;
        VARIABLE tmp : STD_ULOGIC_VECTOR(NUM - 1 DOWNTO 0);
    BEGIN
        -- With no request, no ack regardless of previous grant.
        check("000", "001", "000");
        check("000", "010", "000");
        check("000", "100", "000");

        -- Always ack single requests, regardless of previous grant.
        check("001", "001", "001");
        check("001", "010", "001");
        check("001", "100", "001");
        check("010", "001", "010");
        check("010", "010", "010");
        check("010", "100", "010");
        check("100", "001", "100");
        check("100", "010", "100");
        check("100", "100", "100");

        -- On all requests, grant the one next ot the last granted.
        check("111", "001", "010");
        check("111", "010", "100");
        check("111", "100", "001");

        -- On two request, grant the one that was not last granted.
        check("011", "001", "010");
        check("011", "010", "001");
        check("011", "100", "001");
        check("110", "001", "010");
        check("110", "010", "100");
        check("110", "100", "010");
        check("101", "001", "100");
        check("101", "010", "100");
        check("101", "100", "001");

        -- Report successful test.
        REPORT "Test OK";
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
