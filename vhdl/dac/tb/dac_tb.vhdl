-- =============================================================================
-- File:                    dac_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  dac_tb
--
-- Description:             Testbench for dac entity. Checks if the SPI
--                          communication with the DAC is implemented correctly.
--
-- Changes:                 0.1, 2022-04-29, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY dac_tb IS
    -- Testbench needs no ports.
END ENTITY dac_tb;

ARCHITECTURE simulation OF dac_tb IS
    -- Component definition for device under test.
    COMPONENT dac
        PORT (
            clock, n_reset : IN STD_LOGIC;

            a, b          : IN UNSIGNED(9 DOWNTO 0);
            cs, mosi, clk : OUT STD_LOGIC
        );
    END COMPONENT dac;
    -- Signals for sequential DUTs.
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    -- Signals for connecting to the DUT.
    SIGNAL s_a, s_b : UNSIGNED(9 DOWNTO 0);
    SIGNAL s_cs, s_mosi, s_clk : STD_LOGIC;

    -- Procedure that generates stimuli for the given data. Response form DUT is
    -- checked for correctness.
    PROCEDURE check (
        CONSTANT k    : IN UNSIGNED(9 DOWNTO 0); -- Data to send to the DUT.
        SIGNAL a_or_b : OUT UNSIGNED(9 DOWNTO 0) -- To what channel to send.
    ) IS
    BEGIN
        -- Set dut input.
        a_or_b <= k;
        -- Consume last clock of previous check run. Allows for setting dut
        -- input before it is internally updated.
        WAIT UNTIL rising_edge(s_clock);
        -- Ignore first 8 bits (command + address).
        FOR i IN 7 DOWNTO 0 LOOP
            WAIT UNTIL rising_edge(s_clock);
            -- Chip-Select pin should be low now.
            ASSERT s_cs = '0'
            REPORT "Chip-Select was expected to be low. (start of transaction)"
                SEVERITY failure;
        END LOOP;
        -- Check if data is sent out correctly and with msb first.
        FOR i IN 9 DOWNTO 0 LOOP
            WAIT UNTIL rising_edge(s_clock);
            ASSERT s_mosi = k(i)
            REPORT "Bit " & INTEGER'image(i) & " was sent incorrectly. " &
                "Expected a value of " & STD_LOGIC'image(k(i)) & " but got " &
                STD_LOGIC'image(s_mosi) & "."
                SEVERITY failure;
            ASSERT s_cs = '0'
            REPORT "Chip-Select was expected to be low. (data bits)"
                SEVERITY failure;
        END LOOP;
        -- Consume the remaining 6 dont care bits.
        FOR i IN 5 DOWNTO 0 LOOP
            WAIT UNTIL rising_edge(s_clock);
            ASSERT s_cs = '0'
            REPORT "Chip-Select was expected to be low. (dont-care bits)"
                SEVERITY failure;
        END LOOP;
        -- Wait for FSM to start again, let it run for 7 clocks more. There is
        -- one clock cycle more to wait but it is used in the next call of check
        -- to have the time to set DUT inputs.
        FOR i IN 6 DOWNTO 0 LOOP
            WAIT UNTIL rising_edge(s_clock);
        END LOOP;
    END PROCEDURE check;

BEGIN
    -- Instantiate the device under test.
    dut : dac
    PORT MAP(
        clock   => s_clock,
        n_reset => s_n_reset,
        a       => s_a,
        b       => s_b,
        cs      => s_cs,
        mosi    => s_mosi,
        clk     => s_clk
    );

    -- Clock with 50 MHz.
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 10 ns;

    -- Power on reset the DUT, lasts two clock cycles.
    s_n_reset <= '0', '1' AFTER 40 ns;

    test : PROCESS IS
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(s_clock);

        -- Check every possible data combination where a and b are equal.
        FOR i IN 2 ** 10 - 1 DOWNTO 0 LOOP
            check(to_unsigned(i, 10), s_a);
            check(to_unsigned(i, 10), s_b);
        END LOOP;

        -- Check every possible data combination where a and b are NOT equal.
        FOR i IN 2 ** 10 - 1 DOWNTO 0 LOOP
            check(to_unsigned((2 ** 10 - 1) - i, 10), s_a);
            check(to_unsigned(i, 10), s_b);
        END LOOP;

        -- Report successful test.
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
