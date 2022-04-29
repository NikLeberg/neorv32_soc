-- =============================================================================
-- File:                    dac.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.3
--
-- Entity:                  dac
--
-- Description:             Implements the SPI interface to communicate with the
--                          10 bit Analog Devices LTC2632. The parallel a and b
--                          signals of 10 bits are continously sent out serially
--                          with SPI. Hardware reference:
--                          https://www.analog.com/en/products/ltc2632.html
--
-- Changes:                 0.1, 2022-04-28, leuen4
--                              interface definition
--                          0.2, 2022-04-29, leuen4
--                              initial implementation
--                          0.3, 2022-04-29, leuen4
--                              rename signals for clarity
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY dac IS
    PORT (
        clock, n_reset : IN STD_LOGIC;

        -- 2x 10 bit input signals that will be sent to the DAC. Output voltage
        -- levels are calculated as: Vout = 2.5 V * (k / 2^10)
        a, b : IN UNSIGNED(9 DOWNTO 0);

        -- SPI interface to the DAC. Master-In Slave-Out (MISO) is not required.
        cs, mosi, clk : OUT STD_LOGIC
    );
END ENTITY dac;

ARCHITECTURE no_target_specific OF dac IS
    -- Use a 6 bit counter as FSM state. MSB indicates active channel a or b.
    SIGNAL s_counter : unsigned(5 DOWNTO 0);
    -- Helper signals, MSB of counter and rest of counter except MSB
    SIGNAL s_counter_msb : STD_LOGIC;
    SIGNAL s_counter_lower : UNSIGNED(s_counter'HIGH - 1 DOWNTO 0);

    -- 24 bit shift register.
    SIGNAL s_shift_reg : STD_LOGIC_VECTOR(23 DOWNTO 0);

    -- Command "Write to and Update (Power-Up) DAC n" from table 1 of datasheet.
    CONSTANT c_command_update : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0011";
    -- Address codes for DAC channels from table 1 of datasheet.
    CONSTANT c_address_a : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
    CONSTANT c_address_b : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0001";
    -- Each "command + address + data" is followed by 6 dont care bits.
    CONSTANT c_dont_care : STD_LOGIC_VECTOR(5 DOWNTO 0) := "000000";
BEGIN

    -- =========================================================================
    -- Purpose: State memory i.e. up-counter, with synchronous reset
    -- Type:    sequential
    -- Inputs:  clock, n_reset
    -- Outputs: s_counter
    -- =========================================================================
    count_up : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_counter <= (OTHERS => '0');
            ELSE
                s_counter <= s_counter + 1;
            END IF;
        END IF;
    END PROCESS count_up;
    -- helper signals
    s_counter_msb <= s_counter(s_counter'HIGH);
    s_counter_lower <= s_counter(s_counter'HIGH - 1 DOWNTO 0);

    -- =========================================================================
    -- Purpose: Shift register for serial data output
    -- Type:    sequential
    -- Inputs:  clock, n_reset, s_counter
    -- Outputs: s_shift_reg
    -- =========================================================================
    shift_register : PROCESS (clock) IS
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (n_reset = '0') THEN
                s_shift_reg <= (OTHERS => '0');
            ELSE
                -- On a counter value of 0 (except MSB) init the data for the
                -- shift register. Depending on counter MSB a or b is loaded. On
                -- any other value, the shift register is shifted to the left.
                IF (s_counter_lower = 0) THEN
                    IF (s_counter_msb = '0') THEN
                        s_shift_reg <=
                            c_command_update & c_address_a & STD_LOGIC_VECTOR(a) & c_dont_care;
                    ELSE
                        s_shift_reg <=
                            c_command_update & c_address_b & STD_LOGIC_VECTOR(b) & c_dont_care;
                    END IF;
                ELSE
                    s_shift_reg <=
                        s_shift_reg(s_shift_reg'HIGH - 1 DOWNTO 0) & '0';
                END IF;
            END IF;
        END IF;
    END PROCESS shift_register;

    -- =========================================================================
    -- Purpose: Output logic
    -- Type:    combinational
    -- Inputs:  s_counter, s_last_key
    -- Outputs: new_pressed, new_key
    -- =========================================================================
    -- Data is serially sent out MSB first.
    mosi <= s_shift_reg(s_shift_reg'HIGH);
    -- Chip select is low from count 1 to 25 while valid data is being sent out.
    cs <= '0' WHEN s_counter_lower < 25 AND s_counter_lower /= 0 ELSE
        '1';
    -- Our system is synchronized on the rising clock. As the SPI interface is
    -- also synchronized on the rising edge, use an inverted clock to satisfy
    -- setup and hold timing requirements. See t1 and t2 in figure 1 of
    -- datasheet.
    clk <= NOT clock;

END ARCHITECTURE no_target_specific;
