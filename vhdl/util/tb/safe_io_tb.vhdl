-- =============================================================================
-- File:                    safe_io_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.4
--
-- Entity:                  safe_io_tb
--
-- Description:             Testbench for safe_io entity. Checks if the inputs
--                          are correctly synced and debounced.
--
-- Changes:                 0.1, 2022-04-29, leuen4
--                              initial implementation
--                          0.2, 2022-05-04, leuen4
--                              minor formatting improvements
--                          0.3, 2022-05-08, leuen4
--                              fix check procedure input declarations
--                          0.4, 2022-06-15, leuen4
--                              add new generic input N_SYNC_LENGTH
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY safe_io_tb IS
    -- Testbench needs no ports.
END ENTITY safe_io_tb;

ARCHITECTURE simulation OF safe_io_tb IS
    -- Component definition for device under test.
    COMPONENT safe_io
        GENERIC (
            N_SYNC_LENGTH  : POSITIVE;
            N_COUNTER_BITS : POSITIVE
        );
        PORT (
            clock, n_reset : IN STD_LOGIC;

            x : IN STD_LOGIC;
            y : OUT STD_LOGIC
        );
    END COMPONENT safe_io;
    -- Signals for sequential DUTs.
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    -- Signals for connecting to the DUT.
    SIGNAL s_x, s_y : STD_LOGIC := '0';

BEGIN
    -- Instantiate the device under test.
    dut : safe_io
    GENERIC MAP(
        N_SYNC_LENGTH  => 2, -- sync with 2 flip-flops
        N_COUNTER_BITS => 2  -- total delay of 2^2 + 2 = 6 cycles
    )
    PORT MAP(
        clock   => s_clock,
        n_reset => s_n_reset,
        x       => s_x,
        y       => s_y
    );

    -- Clock with 50 MHz.
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 10 ns;

    -- Power on reset the DUT, lasts two clock cycles.
    s_n_reset <= '0', '1' AFTER 40 ns;

    test : PROCESS IS
        -- Procedure that generates stimuli for the given sequence. Response
        -- from DUT is checked for correctness.
        PROCEDURE check (
            -- Sequence of bits to stimulate the DUT with.
            CONSTANT x : STD_LOGIC_VECTOR(19 DOWNTO 0);
            -- Expected output after t * 20.
            CONSTANT y : STD_LOGIC;
            -- For how long each bit of the sequence is active.
            CONSTANT t : TIME
        ) IS
        BEGIN
            FOR i IN 19 DOWNTO 0 LOOP
                s_x <= x(i);
                WAIT FOR t;
            END LOOP;
            ASSERT s_y = y
            REPORT "Expected y to be " & STD_LOGIC'image(y) & " but got " &
                STD_LOGIC'image(s_y) & "."
                SEVERITY failure;
            -- Restore initial simulation conditions: x is 0, y is 0 and
            -- simulation is in sync with the clock.
            s_x <= '0';
            FOR i IN 5 DOWNTO 0 LOOP
                WAIT UNTIL rising_edge(s_clock);
            END LOOP;
        END PROCEDURE check;
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(s_n_reset);

        -- The clock has a cycle time of 20 ns and the debouncer is configured
        -- to count to 4. Every input signal that holds its level steady for
        -- 4 * 20 ns (at least at the positive clock edges) should be let
        -- through. Note the delay of two additional cycles because of the sync.

        -- Check that hazardous signals aren't let through.
        check("01010101010101010101", '0', 1 ns);
        check("01010101010101010101", '0', 1.1 ns);
        check("10111010001000000010", '0', 9 ns);

        -- Check that valid signals are let through.
        check("11111111111111111111", '1', 20 ns);
        check("00000000000001111110", '1', 20 ns);
        check("00000000000000000000", '0', 20 ns);
        check("11110000111100001111", '0', 20 ns); -- still 0 because of delay

        -- Check that invalid signals aren't let through.
        check("11110000111100001111", '0', 10 ns); -- not steady for long enough
        check("11100011100011100011", '0', 20 ns); -- not steady for 4 clocks
        check("11111011111110111111", '0', 7 ns); -- not steady on pos edge

        -- Report successful test.
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
