-- =============================================================================
-- File:                    geni.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.2
--
-- Entity:                  geni
--
-- Description:             Toplevel entity for geni function generator project.
--                          For a full explanation see: ../README.md
--
-- Changes:                 0.1, 2022-04-20, leuen4
--                              initial version
--                          0.2, 2022-06-26, leuen4
--                              non functional but complete project
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY geni IS
    PORT (
        -- clock and reset signals
        clock, n_reset : IN STD_LOGIC;

        -- Digilent PmodENC interface
        a, b, btn, swt : IN STD_LOGIC;

        -- switch inputs
        sw_on, sw_type, sw_freq, sw_gain, sw_offset, sw_thousand : IN STD_LOGIC;

        -- LED matrix (10 rows x 12 columns, index is row * 12 + column)
        led_matrix : OUT STD_LOGIC_VECTOR((10 * 12) - 1 DOWNTO 0);

        -- 7 segment displays (4x [A, B, C, D, E, F, G, DP])
        seven_seg : OUT STD_LOGIC_VECTOR((4 * 8) - 1 DOWNTO 0);

        -- SPI interface for DAC
        dac_ncs, dac_clk, dac_mosi : OUT STD_LOGIC
    );
END ENTITY geni;

ARCHITECTURE no_target_specific OF geni IS

    -- Definitions for sub entities.

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

    COMPONENT signed_to_unsigned IS
        GENERIC (
            N_BITS_SIGNED   : POSITIVE;
            N_BITS_UNSIGNED : POSITIVE
        );
        PORT (
            x : IN SIGNED(N_BITS_SIGNED - 1 DOWNTO 0);
            y : OUT UNSIGNED(N_BITS_UNSIGNED - 1 DOWNTO 0)
        );
    END COMPONENT signed_to_unsigned;

    COMPONENT dac
        PORT (
            clock, n_reset : IN STD_LOGIC;

            a, b          : IN UNSIGNED(9 DOWNTO 0);
            cs, mosi, clk : OUT STD_LOGIC
        );
    END COMPONENT dac;

    COMPONENT bin_to_bcd
        GENERIC (
            N_BITS : POSITIVE;
            N_BCD  : POSITIVE
        );
        PORT (
            bin : IN SIGNED(N_BITS - 1 DOWNTO 0);
            bcd : OUT STD_LOGIC_VECTOR(N_BCD * 4 DOWNTO 0)
        );
    END COMPONENT bin_to_bcd;

    COMPONENT inc IS
        PORT (
            clock, n_reset : IN STD_LOGIC;

            a, b     : IN STD_LOGIC;
            pos, neg : OUT STD_LOGIC
        );
    END COMPONENT inc;

    COMPONENT safe_io IS
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

    COMPONENT number IS
        PORT (
            clock, n_reset : IN STD_LOGIC;

            up, down   : IN STD_LOGIC;
            next_digit : IN STD_LOGIC;
            enable     : IN STD_LOGIC;

            bin : OUT SIGNED(13 DOWNTO 0);

            seg : OUT STD_LOGIC_VECTOR(4 * 8 - 1 DOWNTO 0)
        );
    END COMPONENT number;

    COMPONENT number_frequency IS
        PORT (
            clock, n_reset : IN STD_LOGIC;

            up, down   : IN STD_LOGIC;
            next_digit : IN STD_LOGIC;
            enable     : IN STD_LOGIC;

            bin : OUT SIGNED(16 DOWNTO 0);

            seg : OUT STD_LOGIC_VECTOR(4 * 8 - 1 DOWNTO 0)
        );
    END COMPONENT number_frequency;

    COMPONENT edge_trigger IS
        PORT (
            clock, n_reset : IN STD_LOGIC;

            x : IN STD_LOGIC;
            y : OUT STD_LOGIC
        );
    END COMPONENT edge_trigger;

    COMPONENT matrix_part IS
        PORT (
            clock, n_reset : IN STD_LOGIC;
            enabled        : IN STD_LOGIC;
            selected       : IN STD_LOGIC;
            parameter      : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            sig_type       : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            led_part       : OUT STD_LOGIC_VECTOR(12 * 5 - 1 DOWNTO 0)
        );
    END COMPONENT matrix_part;

    -- Signals for debunced and synced I/O.
    SIGNAL s_a, s_b, s_btn, s_swt : STD_LOGIC;
    SIGNAL s_sw_on, s_sw_type, s_sw_freq, s_sw_gain, s_sw_offset, s_sw_thousand : STD_LOGIC;

    -- Signals of processed PmodENC pulses.
    SIGNAL s_pos_pulse, s_neg_pulse : STD_LOGIC;

    -- Signals for edge trigger processed button and switches.
    SIGNAL s_btn_pulse, s_sw_on_pulse, s_sw_type_pulse, s_sw_freq_pulse, s_sw_gain_pulse, s_sw_offset_pulse, s_sw_thousand_pulse : STD_LOGIC;

    -- Signals to connect dds sub entities and inputs together.
    SIGNAL s_dds1_out, s_dds2_out : SIGNED(11 DOWNTO 0);
    SIGNAL s_dac1_in, s_dac2_in : UNSIGNED(9 DOWNTO 0);

    -- Signals for connecting bcd digits to the 7 segments.
    SIGNAL s_bcd : STD_LOGIC_VECTOR(4 * 4 DOWNTO 0);

    -- Signals for implementing a simple menu FSM.
    SIGNAL s_param_ch1, s_param_ch2 : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL s_type_ch1, s_type_ch2 : UNSIGNED(1 DOWNTO 0); -- signal type
    SIGNAL s_enabled_ch1, s_enabled_ch2, s_selected_ch1, s_selected_ch2 : STD_LOGIC;

    -- Signals for the different numeric parameters.
    SIGNAL bin_frequency_ch1, bin_frequency_ch2 : SIGNED(16 DOWNTO 0);
    SIGNAL bin_gain_ch1, bin_gain_ch2, bin_offset_ch1, bin_offset_ch2 : SIGNED(13 DOWNTO 0);
    SIGNAL seg_frequency_ch1, seg_frequency_ch2, seg_gain_ch1, seg_gain_ch2, seg_offset_ch1, seg_offset_ch2 : STD_LOGIC_VECTOR(4 * 8 - 1 DOWNTO 0);
    SIGNAL s_en_frequency_ch1, s_en_frequency_ch2, s_en_gain_ch1, s_en_gain_ch2, s_en_offset_ch1, s_en_offset_ch2 : STD_LOGIC;
BEGIN

    -- Make direct I/O signals safe for fpga.
    safe_io_a : safe_io
    GENERIC MAP(
        N_SYNC_LENGTH  => 3,
        N_COUNTER_BITS => 16 -- ~1ms
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => a,
        y       => s_a
    );
    safe_io_b : safe_io
    GENERIC MAP(
        N_SYNC_LENGTH  => 3,
        N_COUNTER_BITS => 16 -- ~1ms
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => b,
        y       => s_b
    );
    safe_io_btn : safe_io
    GENERIC MAP(
        N_SYNC_LENGTH  => 3,
        N_COUNTER_BITS => 16 -- ~1ms
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => btn,
        y       => s_btn
    );
    safe_io_swt : safe_io
    GENERIC MAP(
        N_SYNC_LENGTH  => 3,
        N_COUNTER_BITS => 16 -- ~1ms
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => swt,
        y       => s_swt
    );
    safe_io_sw1 : safe_io
    GENERIC MAP(
        N_SYNC_LENGTH  => 3,
        N_COUNTER_BITS => 18 -- ~5ms
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => sw_on,
        y       => s_sw_on
    );
    safe_io_sw2 : safe_io
    GENERIC MAP(
        N_SYNC_LENGTH  => 3,
        N_COUNTER_BITS => 18 -- ~5ms
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => sw_type,
        y       => s_sw_type
    );
    safe_io_sw3 : safe_io
    GENERIC MAP(
        N_SYNC_LENGTH  => 3,
        N_COUNTER_BITS => 18 -- ~5ms
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => sw_freq,
        y       => s_sw_freq
    );
    safe_io_sw4 : safe_io
    GENERIC MAP(
        N_SYNC_LENGTH  => 3,
        N_COUNTER_BITS => 18 -- ~5ms
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => sw_gain,
        y       => s_sw_gain
    );
    safe_io_sw5 : safe_io
    GENERIC MAP(
        N_SYNC_LENGTH  => 3,
        N_COUNTER_BITS => 18 -- ~5ms
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => sw_offset,
        y       => s_sw_offset
    );
    safe_io_sw6 : safe_io
    GENERIC MAP(
        N_SYNC_LENGTH  => 3,
        N_COUNTER_BITS => 18 -- ~5ms
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => sw_thousand,
        y       => s_sw_thousand
    );
    -- Note that the SW7 which is used as reset signal is not debounced or
    -- synced. For a reset signal this would look a bit different and would
    -- follow a mechanism called "asynchronous asserted, synchronous released"
    -- but for the 50 MHz clock of the current system, this isn't required
    -- according to Mr. Kluter.

    -- Process the a/b signals of the PmodENC into pos/neg pulses.
    inc1 : inc
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        a       => s_a,
        b       => s_b,
        pos     => s_pos_pulse,
        neg     => s_neg_pulse
    );

    -- Detect positive edges of buttons and switches.
    edge1 : edge_trigger
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => s_btn,
        y       => s_btn_pulse
    );
    edge2 : edge_trigger
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => s_sw_on,
        y       => s_sw_on_pulse
    );
    edge3 : edge_trigger
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => s_sw_type,
        y       => s_sw_type_pulse
    );
    edge4 : edge_trigger
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => s_sw_freq,
        y       => s_sw_freq_pulse
    );
    edge5 : edge_trigger
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => s_sw_gain,
        y       => s_sw_gain_pulse
    );
    edge6 : edge_trigger
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => s_sw_offset,
        y       => s_sw_offset_pulse
    );
    edge7 : edge_trigger
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        x       => s_sw_thousand,
        y       => s_sw_thousand_pulse
    );

    -- Instantiate multiple number managers that manage the parameters of both
    -- signal channels.

    number_frequency_ch1 : number_frequency
    PORT MAP(
        clock      => clock,
        n_reset    => n_reset,
        up         => s_pos_pulse,
        down       => s_neg_pulse,
        next_digit => s_btn_pulse,
        enable     => s_en_frequency_ch1,
        bin        => bin_frequency_ch1,
        seg        => seg_frequency_ch1
    );
    number_frequency_ch2 : number_frequency
    PORT MAP(
        clock      => clock,
        n_reset    => n_reset,
        up         => s_pos_pulse,
        down       => s_neg_pulse,
        next_digit => s_btn_pulse,
        enable     => s_en_frequency_ch2,
        bin        => bin_frequency_ch2,
        seg        => seg_frequency_ch2
    );
    number_gain_ch1 : number
    PORT MAP(
        clock      => clock,
        n_reset    => n_reset,
        up         => s_pos_pulse,
        down       => s_neg_pulse,
        next_digit => s_btn_pulse,
        enable     => s_en_gain_ch1,
        bin        => bin_gain_ch1,
        seg        => seg_gain_ch1
    );
    number_gain_ch2 : number
    PORT MAP(
        clock      => clock,
        n_reset    => n_reset,
        up         => s_pos_pulse,
        down       => s_neg_pulse,
        next_digit => s_btn_pulse,
        enable     => s_en_gain_ch2,
        bin        => bin_gain_ch2,
        seg        => seg_gain_ch2
    );
    number_offset_ch1 : number
    PORT MAP(
        clock      => clock,
        n_reset    => n_reset,
        up         => s_pos_pulse,
        down       => s_neg_pulse,
        next_digit => s_btn_pulse,
        enable     => s_en_offset_ch1,
        bin        => bin_offset_ch1,
        seg        => seg_offset_ch1
    );
    number_offset_ch2 : number
    PORT MAP(
        clock      => clock,
        n_reset    => n_reset,
        up         => s_pos_pulse,
        down       => s_neg_pulse,
        next_digit => s_btn_pulse,
        enable     => s_en_offset_ch2,
        bin        => bin_offset_ch2,
        seg        => seg_offset_ch2
    );

    menu_fsm : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_param_ch1 <= (OTHERS => '0');
                s_param_ch2 <= (OTHERS => '0');
                s_type_ch1 <= (OTHERS => '0');
                s_type_ch2 <= (OTHERS => '0');
                s_enabled_ch1 <= '0';
                s_enabled_ch2 <= '0';
            ELSE
                -- Enable or disable selected channel.
                IF (s_sw_on_pulse = '1') THEN
                    IF (s_selected_ch1 = '1') THEN
                        s_enabled_ch1 <= NOT s_enabled_ch1;
                    ELSE
                        s_enabled_ch2 <= NOT s_enabled_ch2;
                    END IF;
                END IF;
                -- Advance signal type of selected channel.
                IF (s_sw_type_pulse = '1') THEN
                    IF (s_selected_ch1 = '1') THEN
                        s_type_ch1 <= s_type_ch1 + 1;
                        s_param_ch1 <= "00";
                    ELSE
                        s_type_ch2 <= s_type_ch2 + 1;
                        s_param_ch2 <= "00";
                    END IF;
                END IF;
                -- Display frequency on 7 segment digits.
                IF (s_sw_freq_pulse = '1') THEN
                    IF (s_selected_ch1 = '1') THEN
                        s_param_ch1 <= "01";
                    ELSE
                        s_param_ch2 <= "01";
                    END IF;
                END IF;
                -- Display gain on 7 segment digits.
                IF (s_sw_gain_pulse = '1') THEN
                    IF (s_selected_ch1 = '1') THEN
                        s_param_ch1 <= "10";
                    ELSE
                        s_param_ch2 <= "10";
                    END IF;
                END IF;
                -- Display gain on 7 segment digits.
                IF (s_sw_offset_pulse = '1') THEN
                    IF (s_selected_ch1 = '1') THEN
                        s_param_ch1 <= "11";
                    ELSE
                        s_param_ch2 <= "11";
                    END IF;
                END IF;

                --s_sw_thousand_pulse : STD_LOGIC;

                -- "00": Sine, "01": Rectangle, "10": Triangle, "11": Sawtooth
            END IF;
        END IF;
    END PROCESS menu_fsm;

    display_fsm : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                seven_seg <= (OTHERS => '0');
            ELSE
                s_en_frequency_ch1 <= '0';
                s_en_frequency_ch2 <= '0';
                s_en_gain_ch1 <= '0';
                s_en_gain_ch2 <= '0';
                s_en_offset_ch1 <= '0';
                s_en_offset_ch2 <= '0';
                IF (s_selected_ch1 = '1') THEN
                    CASE s_param_ch1 IS
                        WHEN "00" => -- type
                            seven_seg <= (OTHERS => '0');
                        WHEN "01" => -- frequency
                            seven_seg <= seg_frequency_ch1;
                            s_en_frequency_ch1 <= '1';
                        WHEN "10" => -- gain
                            seven_seg <= seg_gain_ch1;
                            s_en_gain_ch1 <= '1';
                        WHEN "11" => -- offset
                            seven_seg <= seg_offset_ch1;
                            s_en_offset_ch1 <= '1';
                        WHEN OTHERS => -- invalid parameter
                            seven_seg <= (OTHERS => '0');
                    END CASE;
                ELSE
                    CASE s_param_ch2 IS
                        WHEN "00" => -- type
                            seven_seg <= (OTHERS => '0');
                        WHEN "01" => -- frequency
                            seven_seg <= seg_frequency_ch2;
                            s_en_frequency_ch2 <= '1';
                        WHEN "10" => -- gain
                            seven_seg <= seg_gain_ch2;
                            s_en_gain_ch2 <= '1';
                        WHEN "11" => -- offset
                            seven_seg <= seg_offset_ch2;
                            s_en_offset_ch2 <= '1';
                        WHEN OTHERS => -- invalid parameter
                            seven_seg <= (OTHERS => '0');
                    END CASE;
                END IF;
            END IF;
        END IF;
    END PROCESS display_fsm;

    s_selected_ch1 <= s_swt;
    s_selected_ch2 <= NOT s_swt;

    matrix_ch1 : matrix_part
    PORT MAP(
        clock     => clock,
        n_reset   => n_reset,
        enabled   => s_enabled_ch1,
        selected  => s_selected_ch1,
        parameter => s_param_ch1,
        sig_type  => STD_LOGIC_VECTOR(s_type_ch1),
        led_part  => led_matrix(5 * 12 - 1 DOWNTO 0)
    );
    matrix_ch2 : matrix_part
    PORT MAP(
        clock     => clock,
        n_reset   => n_reset,
        enabled   => s_enabled_ch2,
        selected  => s_selected_ch2,
        parameter => s_param_ch2,
        sig_type  => STD_LOGIC_VECTOR(s_type_ch2),
        led_part  => led_matrix(10 * 12 - 1 DOWNTO 5 * 12)
    );
    -- Instantiate two DDS.
    dds1 : dds
    PORT MAP(
        clock        => clock,
        n_reset      => n_reset,
        sig_type     => STD_LOGIC_VECTOR(s_type_ch1),
        frequency_in => UNSIGNED(bin_frequency_ch1),
        gain_in      => UNSIGNED(bin_gain_ch1(6 DOWNTO 0)),
        offset_in    => UNSIGNED(bin_offset_ch1(7 DOWNTO 0)),
        value        => s_dds1_out
    );
    dds2 : dds
    PORT MAP(
        clock        => clock,
        n_reset      => n_reset,
        sig_type     => STD_LOGIC_VECTOR(s_type_ch2),
        frequency_in => UNSIGNED(bin_frequency_ch2),
        gain_in      => UNSIGNED(bin_gain_ch2(6 DOWNTO 0)),
        offset_in    => UNSIGNED(bin_offset_ch2(7 DOWNTO 0)),
        value        => s_dds2_out
    );

    -- Instantiate two value converters.
    s2u1 : signed_to_unsigned
    GENERIC MAP(
        N_BITS_SIGNED   => 12,
        N_BITS_UNSIGNED => 10
    )
    PORT MAP(
        x => s_dds1_out,
        y => s_dac1_in
    );
    s2u2 : signed_to_unsigned
    GENERIC MAP(
        N_BITS_SIGNED   => 12,
        N_BITS_UNSIGNED => 10
    )
    PORT MAP(
        x => s_dds2_out,
        y => s_dac2_in
    );

    -- Instantiate a DAC that gets both DDS channels as inputs.
    dac1 : dac
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        a       => s_dac1_in,
        b       => s_dac2_in,
        cs      => dac_ncs,
        mosi    => dac_mosi,
        clk     => dac_clk
    );

END ARCHITECTURE no_target_specific;
