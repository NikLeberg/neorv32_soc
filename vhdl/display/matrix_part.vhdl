-- =============================================================================
-- File:                    matrix_part.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  matrix_part
--
-- Description:             Display channel status and selected parameter on one
--                          half of the LED Matrix.
--
-- Changes:                 0.1, 2022-06-26, leuen4
--                              initial implementation
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY matrix_part IS
    PORT (
        clock, n_reset : IN STD_LOGIC;

        enabled  : IN STD_LOGIC; -- '1' if channel is enabled
        selected : IN STD_LOGIC; -- '1' if channel is selected for edit

        -- Parameter type is one of:
        -- "00": Type, "01": Frequency, "10": Gain, "11": Offset
        parameter : IN STD_LOGIC_VECTOR(1 DOWNTO 0);

        -- Signal type is one of:
        -- "00": Sine, "01": Rectangle, "10": Triangle, "11": Sawtooth
        sig_type : IN STD_LOGIC_VECTOR(1 DOWNTO 0);

        led_part : OUT STD_LOGIC_VECTOR(12 * 5 - 1 DOWNTO 0)
    );
END ENTITY matrix_part;

ARCHITECTURE no_target_specific OF matrix_part IS

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

    -- Constants for signal type display. Fills first 8 pixels per line.
    -- Constants are arranged line by line.
    TYPE sig_display_type IS ARRAY(4 DOWNTO 0) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
    CONSTANT c_sig_none : sig_display_type := (OTHERS => (OTHERS => '0'));
    CONSTANT c_sig_off : sig_display_type := (
        "00000000",
        "00000000",
        "11111110",
        "00000000",
        "00000000"
    );
    CONSTANT c_sig_sine : sig_display_type := (
        "00000000",
        "01100000",
        "10010010",
        "00001100",
        "00000000"
    );
    CONSTANT c_sig_rect : sig_display_type := (
        "00000000",
        "00011110",
        "00010000",
        "11110000",
        "00000000"
    );
    CONSTANT c_sig_triangle : sig_display_type := (
        "00000000",
        "00100010",
        "01010100",
        "10001000",
        "00000000"
    );
    CONSTANT c_sig_saw : sig_display_type := (
        "00000000",
        "00001110",
        "00110010",
        "11000010",
        "00000000"
    );

    -- Constants for parameter type display. Fills last 4 pixels per line.
    -- Constants are arranged line by line.
    TYPE par_display_type IS ARRAY(4 DOWNTO 0) OF STD_LOGIC_VECTOR(3 DOWNTO 0);
    CONSTANT c_par_none : par_display_type := (OTHERS => (OTHERS => '0'));
    CONSTANT c_par_type : par_display_type := c_par_none;
    CONSTANT c_par_freq : par_display_type := (
        "0000",
        "0111",
        "0100",
        "0110",
        "0100"
    ); -- "F"
    CONSTANT c_par_gain : par_display_type := (
        "0000",
        "0010",
        "0101",
        "0111",
        "0101"
    ); -- "A"
    CONSTANT c_par_offset : par_display_type := (
        "0000",
        "0010",
        "0101",
        "0101",
        "0010"
    ); -- "O"

    -- Signals of the current display.
    SIGNAL s_type : sig_display_type;
    SIGNAL s_parameter : par_display_type;

    -- Blinking signal.
    SIGNAL s_pwm, s_blink : STD_LOGIC;

    -- Intermediate signal for flipping matrix pixels.
    SIGNAL led_flip : STD_LOGIC_VECTOR(12 * 5 - 1 DOWNTO 0);

BEGIN

    -- =========================================================================
    -- Purpose: Contitionally assign constants to display on selected parameter.
    -- Type:    combinational
    -- Inputs:  s_blink, parameter, enabled, selected, sig_type
    -- Outputs: s_parameter, s_type
    -- =========================================================================
    -- "00": Type, "01": Frequency, "10": Gain, "11": Offset
    s_parameter <= c_par_none WHEN selected = '0' ELSE
        c_par_none WHEN s_blink = '1' ELSE
        c_par_type WHEN parameter = "00" ELSE
        c_par_freq WHEN parameter = "01" ELSE
        c_par_gain WHEN parameter = "10" ELSE
        c_par_offset;
    -- "00": Sine, "01": Rectangle, "10": Triangle, "11": Sawtooth
    s_type <= c_sig_none WHEN (s_blink = '1' AND parameter = "00") ELSE
        c_sig_off WHEN enabled = '0' ELSE
        c_sig_sine WHEN sig_type = "00" ELSE
        c_sig_rect WHEN sig_type = "01" ELSE
        c_sig_triangle WHEN sig_type = "10" ELSE
        c_sig_saw;

    -- =========================================================================
    -- Purpose: Transform piecewise defined signals to led matrix output.
    -- Type:    combinational
    -- Inputs:  s_type, s_parameter
    -- Outputs: led_flip
    -- =========================================================================
    -- Interate over lines and combine output piecewise from current signals.
    assign_output : FOR i IN 4 DOWNTO 0 GENERATE -- iterate over lines
        led_flip((i + 1) * 12 - 1 DOWNTO i * 12) <= s_type(i) & s_parameter(i);
    END GENERATE;

    -- =========================================================================
    -- Purpose: Flip output bits so that matrix is left to right.
    -- Type:    combinational
    -- Inputs:  led_flip
    -- Outputs: led_part
    -- =========================================================================
    flip_bits : FOR i IN led_flip'LEFT DOWNTO 0 GENERATE
        led_part(led_part'LEFT - i) <= led_flip(i);
    END GENERATE;

    -- =========================================================================
    -- Purpose: Instantiate pwm with frequency of 3 Hz and a duty of 50 %.
    -- Type:    sequential
    -- Inputs:  clock, n_reset
    -- Outputs: s_blink
    -- =========================================================================
    fixed_pwm1 : fixed_pwm
    GENERIC MAP(
        N_BITS     => 24,
        COUNT_MAX  => 2 ** 24 - 1,
        COUNT_HIGH => 0,
        COUNT_LOW  => 2 ** (24 - 1) - 1
    )
    PORT MAP(
        clock   => clock,
        n_reset => n_reset,
        pwm     => s_pwm
    );

    -- =========================================================================
    -- Purpose: Enable blinking if channel is selected and pwm signal is high.
    -- Type:    combinational
    -- Inputs:  s_pwm, selected
    -- Outputs: s_blink
    -- =========================================================================
    s_blink <= s_pwm AND selected;

END ARCHITECTURE no_target_specific;
