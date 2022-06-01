-- =============================================================================
-- File:                    dds_tb.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  dds_tb
--
-- Description:             Testbench for dds entity. The dds entity is built
--                          from many sub entities which are all well tested.
--                          This "top" testbench only tests if the combined
--                          system can be compiled and instantiated. Also it
--                          serves as a manual / visual test that can be run
--                          with script ./scripts/modelsim_open.tcl
--
-- Changes:                 0.1, 2022-05-09, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY dds_tb IS
    -- Testbench needs no ports.
END ENTITY dds_tb;

ARCHITECTURE simulation OF dds_tb IS
    -- Component definition for device under test.
    COMPONENT dds
        PORT (
            clock, n_reset : IN STD_LOGIC;

            sig_type     : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            frequency_in : IN UNSIGNED(16 DOWNTO 0);
            gain_in      : IN UNSIGNED(6 DOWNTO 0);
            offset_in    : IN UNSIGNED(7 DOWNTO 0);
            value        : OUT SIGNED(11 DOWNTO 0)
        );
    END COMPONENT dds;
    -- Signals for sequential DUTs.
    SIGNAL s_clock : STD_LOGIC := '1';
    SIGNAL s_n_reset : STD_LOGIC := '0';
    SIGNAL s_done : STD_LOGIC := '0';
    -- Signals for connecting to the DUT.
    SIGNAL s_sig_type : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";
    SIGNAL s_frequency : UNSIGNED(16 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_gain : UNSIGNED(6 DOWNTO 0) := (OTHERS => '1');
    SIGNAL s_offset : UNSIGNED(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_value : SIGNED(11 DOWNTO 0) := (OTHERS => '0');
BEGIN
    -- Instantiate the device under test.
    dut : dds
    PORT MAP(
        clock        => s_clock,
        n_reset      => s_n_reset,
        sig_type     => s_sig_type,
        frequency_in => s_frequency,
        gain_in      => s_gain,
        offset_in    => s_offset,
        value        => s_value
    );

    -- Clock with 50 MHz.
    s_clock <= '0' WHEN s_done = '1' ELSE
        NOT s_clock AFTER 10 ns;

    -- Power on reset the DUT, lasts two clock cycles.
    s_n_reset <= '0', '1' AFTER 40 ns;

    test : PROCESS IS
        -- Procedure that generates stimuli for the given wave parameters. The
        -- resulting wave is NOT checked for correctness.
        PROCEDURE check (
            CONSTANT sig_type  : INTEGER; -- 0: sine, 1: rect, 2: trig, 3: saw
            CONSTANT frequency : INTEGER; -- desired frequency
            CONSTANT gain      : INTEGER; -- desired gain
            CONSTANT offset    : INTEGER  -- desired offset
        ) IS
        BEGIN
            s_sig_type <= STD_LOGIC_VECTOR(to_unsigned(sig_type, 2));
            s_frequency <= to_unsigned(frequency, 17);
            s_gain <= to_unsigned(gain, 7);
            s_offset <= to_unsigned(offset, 8);
            -- Wait for one full wave period.
            WAIT FOR (REAL(1e9) / REAL(frequency)) * 1 ns;
            WAIT UNTIL rising_edge(s_clock); -- sync to clock
        END PROCEDURE check;
    BEGIN
        -- Wait for power on reset to finish.
        WAIT UNTIL rising_edge(s_n_reset);

        -- A sine with 10 kHz and full amplitude.
        check(0, 10000, 127, 0);

        -- A sine with 1 kHz and full amplitude.
        check(0, 1000, 127, 0);

        -- A square wave with 100 Hz and small amplitude.
        check(1, 100, 60, 0);

        -- A square wave with 100 Hz, small amplitude and some offset.
        check(1, 100, 60, 60);

        -- Report successful test.
        REPORT "Test OK";
        s_done <= '1';
        WAIT;
    END PROCESS test;
END ARCHITECTURE simulation;
