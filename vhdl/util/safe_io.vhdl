-- =============================================================================
-- File:                    safe_io.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.3
--
-- Entity:                  safe_io
--
-- Description:             Processes direct I/O pins and makes them usable for
--                          inside the FPGA. The input gets synchronized to the
--                          clock and debounced. Count of clock cycles for
--                          debounce can be configured with generic input. The N
--                          value defines how many (2^N) clocks the input has to
--                          be stable before a level change is allowed. Note
--                          that the total delay for the signal is
--                          2^N_COUNTER_BITS + N_SYNC_LENGTH.
--
-- Changes:                 0.1, 2022-04-29, leuen4
--                              initial implementation
--                          0.2, 2022-05-04, leuen4
--                              minor formatting improvements
--                          0.3, 2022-06-15, leuen4
--                              fix naming "hazard -> metastability" and extend
--                              with generic syncronizer length
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY safe_io IS
    GENERIC (
        N_SYNC_LENGTH  : POSITIVE := 3; -- length of synchronizer
        N_COUNTER_BITS : POSITIVE := 2  -- width for counter, counts to 2^N
    );
    PORT (
        clock, n_reset : IN STD_LOGIC;

        x : IN STD_LOGIC; -- unsafe, unsynchronized, bouncy, direct I/O pin
        y : OUT STD_LOGIC -- safe, synchronized, debounced, FPGA signal
    );
END ENTITY safe_io;

ARCHITECTURE no_target_specific OF safe_io IS
    -- Signals for shift register i.e. multiple flip-flops in a row.
    SIGNAL s_sync : STD_LOGIC_VECTOR(N_SYNC_LENGTH - 1 DOWNTO 0);
    SIGNAL s_synced : STD_LOGIC;

    -- Signals for debouncer i.e. up-counter.
    SIGNAL s_count : UNSIGNED(N_COUNTER_BITS - 1 DOWNTO 0);
    CONSTANT c_max_count : UNSIGNED(N_COUNTER_BITS - 1 DOWNTO 0) := to_unsigned(2 ** N_COUNTER_BITS - 1, N_COUNTER_BITS);
    SIGNAL s_debounced : STD_LOGIC;
BEGIN

    -- =========================================================================
    -- Purpose: Synchronize input to clock for metastability prevention
    -- Type:    sequential
    -- Inputs:  clock, n_reset, x
    -- Outputs: s_sync, s_synced
    -- =========================================================================
    anti_hazard : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_sync <= (OTHERS => '0');
            ELSE
                -- Route direct I/O through multiple flip-flops.
                s_sync <= s_sync(s_sync'HIGH - 1 DOWNTO 0) & x;
            END IF;
        END IF;
    END PROCESS anti_hazard;
    -- Helper signal, attached to the end of flip-flops.
    s_synced <= s_sync(s_sync'HIGH);

    -- =========================================================================
    -- Purpose: Debounce input for 2^N clocks
    -- Type:    sequential
    -- Inputs:  clock, n_reset, s_synced, s_debounced
    -- Outputs: s_count, s_debounced
    -- =========================================================================
    debounce : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_count <= (OTHERS => '0');
                s_debounced <= '0';
            ELSE
                -- Count up if input level has changed. If it changes back, the
                -- counter is reset to zero. Only if the change has lasted for
                -- more than 2^N clocks it is let trought.
                IF (s_synced /= s_debounced) THEN
                    s_count <= s_count + 1;
                ELSE
                    s_count <= (OTHERS => '0');
                END IF;
                IF (s_count = c_max_count) THEN
                    s_debounced <= s_synced;
                END IF;
            END IF;
        END IF;
    END PROCESS debounce;

    -- Output the now synchronized and debounced input.
    y <= s_debounced;

END ARCHITECTURE no_target_specific;
