-- =============================================================================
-- File:                    number_frequency.vhdl
--
-- Authors:                 Reusser Adrian <reusa1@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  number_frequency
--
-- Description:             Manages a number based on bcd digits. With up- or
--                          downcount pulses and an digit selection with a push
--                          button the number can be nodified. The number is
--                          displayed on a 7 segment display and the currently
--                          selected digit is blinking. As output is also the
--                          number in binary form available.
--
-- Changes:                 0.1, 2022-06-26, reusa1
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY number_frequency IS
    PORT (
        clock, n_reset : IN STD_LOGIC;

        up, down   : IN STD_LOGIC; -- pulses to count up or down
        next_digit : IN STD_LOGIC; -- switch to next digit
        enable     : IN STD_LOGIC; -- enable counting up/down

        bin : OUT SIGNED(16 DOWNTO 0); -- binary number output

        seg : OUT STD_LOGIC_VECTOR(4 * 8 - 1 DOWNTO 0) -- 4 * 7 segments + DP
    );
END ENTITY number_frequency;

ARCHITECTURE no_target_specific OF number_frequency IS

    -- define component bcd_digit
    COMPONENT bcd_digit IS
        PORT (
            clock, n_reset       : IN STD_LOGIC;
            up, down             : IN STD_LOGIC;
            enable               : IN STD_LOGIC;
            prev_digit_overflow  : IN STD_LOGIC;
            prev_digit_underflow : IN STD_LOGIC;
            overflow, underflow  : OUT STD_LOGIC;
            bcd                  : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
        );
    END COMPONENT bcd_digit;
    -- define component bcd_to_7seg
    COMPONENT bcd_to_7seg IS
        GENERIC (
            N_BCD  : POSITIVE;
            N_DP   : NATURAL;
            E_SIGN : NATURAL
        );
        PORT (
            bcd : IN STD_LOGIC_VECTOR(N_BCD * 4 DOWNTO 0);
            seg : OUT STD_LOGIC_VECTOR((N_BCD + E_SIGN) * 8 - 1 DOWNTO 0)
        );
    END COMPONENT bcd_to_7seg;
    -- define component fixed_pwm
    COMPONENT fixed_pwm IS
        GENERIC (
            N_BITS     : POSITIVE;
            COUNT_MAX  : POSITIVE;
            COUNT_HIGH : NATURAL;
            COUNT_LOW  : NATURAL
        );
        PORT (
            clock, n_reset : IN STD_LOGIC;
            pwm            : OUT STD_LOGIC
        );
    END COMPONENT fixed_pwm;
    --define component bcd_to_bin
    COMPONENT bcd_to_bin IS
        GENERIC (
            N_BCD  : POSITIVE;
            N_BITS : POSITIVE
        );
        PORT (
            bcd : IN STD_LOGIC_VECTOR(N_BCD * 4 DOWNTO 0);
            bin : OUT SIGNED(N_BITS - 1 DOWNTO 0)
        );
    END COMPONENT bcd_to_bin;

    -- Signals for active digit counter / selector.
    SIGNAL s_current, s_next : UNSIGNED(1 DOWNTO 0);

    -- Signals for wiring the multiple digits together.
    SIGNAL s_overflow, s_underflow, s_enable : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL s_prev_digit_overflow, s_prev_digit_underflow : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL s_bcd : STD_LOGIC_VECTOR(4 * 4 DOWNTO 0);

    -- Signals for converting bcd to 7seg representation and letting the current
    -- digit blink.
    SIGNAL s_seg : STD_LOGIC_VECTOR(4 * 8 - 1 DOWNTO 0);
    SIGNAL s_blink : STD_LOGIC;
BEGIN

    -- State memory for digit counter / selector.
    state_memory : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_current <= (OTHERS => '0');
            ELSE
                s_current <= s_next;
            END IF;
        END IF;
    END PROCESS state_memory;

    -- Next state logic for digit counter / selector.
    s_next <= s_current + 1 WHEN next_digit = '1' ELSE
        s_current;

    -- Manage the bcd number with multiple bcd digit counters.
    digit : FOR i IN 3 DOWNTO 0 GENERATE
        -- Instantiate 4 bcd digits.
        bcd_digit_i : bcd_digit
        PORT MAP(
            clock                => clock,
            n_reset              => n_reset,
            up                   => up,
            down                 => down,
            enable               => s_enable(i),
            prev_digit_overflow  => s_prev_digit_overflow(i),
            prev_digit_underflow => s_prev_digit_underflow(i),
            overflow             => s_overflow(i),
            underflow            => s_underflow(i),
            bcd                  => s_bcd((i + 1) * 4 - 1 DOWNTO i * 4)
        );
        -- Wire over- and underflows together.
        prev_digit_0 : IF i = 0 GENERATE
            s_prev_digit_overflow(i) <= '0';
            s_prev_digit_underflow(i) <= '0';
        END GENERATE;
        prev_digit : IF i /= 0 GENERATE
            s_prev_digit_overflow(i) <= s_overflow(i - 1);
            s_prev_digit_underflow(i) <= s_underflow(i - 1);
        END GENERATE;
        -- Digit is enabled when counter points to it and this is enabled.
        s_enable(i) <= '1' WHEN (s_current = to_unsigned(i, 2) AND enable = '1') ELSE
        '0';
    END GENERATE;
    -- MSB signales sign, always positive.
    s_bcd(s_bcd'HIGH) <= '0';

    -- Convert bcd digit to 7 seg representation.
    bcd_to_7seg1 : bcd_to_7seg
    GENERIC MAP(
        N_BCD  => 4,
        N_DP   => 0,
        E_SIGN => 0
    )
    PORT MAP(
        bcd => s_bcd,
        seg => s_seg
    );

    -- Make the currently selected digit blink on the 7 segment display.
    fixed_pwm1 : fixed_pwm
    GENERIC MAP(
        N_BITS     => 25, -- frequency of 1.5 Hz
        COUNT_MAX  => 2 ** 25 - 1,
        COUNT_HIGH => 0,
        COUNT_LOW  => 2 ** (25 - 3) - 1 -- duty of 50 %
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        pwm     => s_blink
    );
    seg_digit : PROCESS (s_seg, s_blink, s_current) IS
        VARIABLE seg_value : STD_LOGIC_VECTOR(7 DOWNTO 0);
    BEGIN
        FOR i IN 3 DOWNTO 0 LOOP
            IF (s_current = to_unsigned(i, 2) AND s_blink = '1') THEN
                seg_value := (OTHERS => '0');
            ELSE
                seg_value := s_seg((i + 1) * 8 - 1 DOWNTO i * 8);
            END IF;
            seg((i + 1) * 8 - 1 DOWNTO i * 8) <= seg_value;
        END LOOP;
    END PROCESS seg_digit;

    -- Convert bcd number to binary representation.
    bcd_to_bin1 : bcd_to_bin
    GENERIC MAP(
        N_BCD  => 4,
        N_BITS => 17
    )
    PORT MAP(
        bcd => s_bcd,
        bin => bin
    );

END ARCHITECTURE no_target_specific;
