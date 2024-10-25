-- =============================================================================
-- File:                    gcd.vhdl
--
-- Entity:                  gcd
--
-- Description:             Greatest common divisor calculation as NIOS II
--                          hardware accelerator.
--
-- Author:                  Niklaus Leuenberger <@NikLeberg>
--
-- SPDX-License-Identifier: MIT
--
-- Version:                 0.1
--
-- Changes:                 0.1, 2023-01-09, NikLeberg
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY gcd IS
    GENERIC (
        NBITS : POSITIVE := 32 -- width of data
    );
    PORT (
        clk    : IN STD_LOGIC := '0'; -- clock of the algorithm
        clk_en : IN STD_LOGIC := '0'; -- clock enable of the algorithm
        start  : IN STD_LOGIC := '0'; -- strobe to start the algorithm
        reset  : IN STD_LOGIC := '0'; -- reset of the algorithm

        dataa : IN UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0'); -- first input number
        datab : IN UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0'); -- second input number

        done  : OUT STD_LOGIC := '0'; -- strobe to signal that the algorithm is done
        ready : OUT STD_LOGIC := '1'; -- signal that the block is ready for a new calculation

        result : OUT UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0') -- calculated result
    );
END ENTITY gcd;

ARCHITECTURE no_target_specific OF gcd IS

    -- registers with the current and next intermediate numbers
    SIGNAL s_a, s_next_a : UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_b, s_next_b : UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_n, s_next_n : UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0');

    -- helper signals of input numbers
    SIGNAL s_a_even, s_b_even : STD_LOGIC := '0';
    SIGNAL s_a_gt_b : STD_LOGIC := '0';

    -- controller FSM signals
    TYPE state_type IS (STATE_IDLE, STATE_INIT, STATE_CALC, STATE_FINISH, STATE_DONE);
    SIGNAL s_state, s_next_state : state_type;

BEGIN

    -- =========================================================================
    -- Purpose: State memory of controller FSM with synchronous reset
    -- Type:    sequential
    -- Inputs:  clk, clk_en, reset, s_next_state
    -- Outputs: s_state
    -- =========================================================================
    state_memory : PROCESS (clk) IS
    BEGIN
        IF (rising_edge(clk)) THEN
            IF (clk_en = '1') THEN
                IF (reset = '1') THEN
                    s_state <= STATE_IDLE;
                ELSE
                    s_state <= s_next_state;
                END IF;
            END IF;
        END IF;
    END PROCESS state_memory;

    -- =========================================================================
    -- Purpose: Next state logic of controller FSM
    -- Type:    combinational
    -- Inputs:  s_state, start, s_a, s_b
    -- Outputs: s_next_state
    -- =========================================================================
    state_nsl : PROCESS (s_state, start, s_a, s_b) IS
    BEGIN
        s_next_state <= s_state;
        CASE s_state IS
            WHEN STATE_IDLE => -- start of operation
                IF start = '1' THEN
                    s_next_state <= STATE_INIT;
                END IF;
            WHEN STATE_INIT => -- initialize algorithm
                s_next_state <= STATE_CALC;
            WHEN STATE_CALC => -- calculate result
                IF s_a = s_b THEN
                    s_next_state <= STATE_FINISH;
                END IF;
            WHEN STATE_FINISH => -- result calculated, finish up
                s_next_state <= STATE_DONE;
            WHEN STATE_DONE => -- done
                s_next_state <= STATE_IDLE;
            WHEN OTHERS =>
                s_next_state <= STATE_IDLE;
        END CASE;
    END PROCESS state_nsl;

    -- =========================================================================
    -- Purpose: Output logic of controller FSM
    -- Type:    combinational
    -- Inputs:  s_state
    -- Outputs: done, ready
    -- =========================================================================
    done <= '1' WHEN s_state = STATE_DONE ELSE
        '0';
    ready <= '1' WHEN s_state = STATE_IDLE ELSE
        '0';

    -- =========================================================================
    -- Purpose: State memory of "abn" datapath, no reset
    -- Type:    sequential
    -- Inputs:  s_next_a, s_next_b, s_next_n
    -- Outputs: s_a, s_b, s_n
    -- =========================================================================
    data_memory : PROCESS (clk) IS
    BEGIN
        IF (rising_edge(clk)) THEN
            IF (s_state = STATE_INIT OR s_state = STATE_CALC) THEN
                s_a <= s_next_a;
                s_b <= s_next_b;
                s_n <= s_next_n;
            END IF;
        END IF;
    END PROCESS data_memory;

    -- =========================================================================
    -- Purpose: Create helper signals for evenness and sizes of a & b.
    -- Type:    combinational
    -- Inputs:  s_dataa, s_datab
    -- Outputs: s_dataa_even, s_datab_even
    -- =========================================================================
    s_a_even <= '0' WHEN s_a(0) = '1' ELSE
        '1';
    s_b_even <= '0' WHEN s_b(0) = '1' ELSE
        '1';
    s_a_gt_b <= '1' WHEN s_a > s_b ELSE
        '0';

    -- =========================================================================
    -- Purpose: Next state logic of "a" number
    -- Type:    combinational
    -- Inputs:  dataa, s_a, s_b, s_state, s_a_even, s_b_even, s_a_gt_b
    -- Outputs: s_next_a
    -- =========================================================================
    a_nsl : PROCESS (dataa, s_a, s_b, s_state, s_a_even, s_b_even, s_a_gt_b) IS
    BEGIN
        IF (s_state = STATE_INIT) THEN
            s_next_a <= dataa;
        ELSIF (s_state /= STATE_CALC) THEN
            s_next_a <= s_a;
        ELSE
            IF (s_a_even = '1') THEN
                s_next_a <= ('0' & s_a(NBITS - 1 DOWNTO 1)); -- a >>= 1
            ELSIF (s_b_even = '0' AND s_a_gt_b = '1') THEN
                s_next_a <= s_a - s_b; -- a -= b
            ELSE
                s_next_a <= s_a;
            END IF;
        END IF;
    END PROCESS a_nsl;

    -- =========================================================================
    -- Purpose: Next state logic of "b" number
    -- Type:    combinational
    -- Inputs:  datab, s_a, s_b, s_state, s_b_even, s_a_gt_b
    -- Outputs: s_next_b
    -- =========================================================================
    b_nsl : PROCESS (datab, s_a, s_b, s_state, s_b_even, s_a_gt_b) IS
    BEGIN
        IF (s_state = STATE_INIT) THEN
            s_next_b <= datab;
        ELSIF (s_state /= STATE_CALC) THEN
            s_next_b <= s_b;
        ELSE
            IF (s_b_even = '1') THEN
                s_next_b <= ('0' & s_b(NBITS - 1 DOWNTO 1)); -- b >>= 1
            ELSIF (s_a_gt_b = '0') THEN
                s_next_b <= s_b - s_a; -- b -= a
            ELSE
                s_next_b <= s_b;
            END IF;
        END IF;
    END PROCESS b_nsl;

    -- =========================================================================
    -- Purpose: Next state logic of "n" number
    -- Type:    combinational
    -- Inputs:  s_n, s_a_even, s_b_even
    -- Outputs: s_next_n
    -- =========================================================================
    n_nsl : PROCESS (s_state, s_a_even, s_b_even, s_n) IS
    BEGIN
        IF (s_state = STATE_INIT) THEN
            s_next_n <= (OTHERS => '0');
        ELSIF (s_state /= STATE_CALC) THEN
            s_next_n <= s_n;
        ELSE
            IF (s_a_even = '1' AND s_b_even = '1') THEN
                s_next_n <= s_n + 1; -- n++
            ELSE
                s_next_n <= s_n;
            END IF;
        END IF;
    END PROCESS n_nsl;

    -- =========================================================================
    -- Purpose: Result memory with final shift operation
    -- Type:    sequential
    -- Inputs:  clk, reset, s_a, s_n
    -- Outputs: result
    -- =========================================================================
    result_memory : PROCESS (clk) IS
        CONSTANT c_zero : UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0');
    BEGIN
        IF (rising_edge(clk)) THEN
            IF (reset = '1') THEN
                result <= (OTHERS => '0');
            ELSIF (s_state = STATE_FINISH) THEN
                result <= shift_left(s_a, to_integer(s_n));
                -- result <= s_a(NBITS - 1 - to_integer(s_n) DOWNTO 0) & c_zero(to_integer(s_n) - 1 DOWNTO 0);
            END IF;
        END IF;
    END PROCESS result_memory;

END ARCHITECTURE no_target_specific;
