-- =============================================================================
-- File:                    dac.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
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
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY dac IS
    PORT (
        clock, n_reset : IN STD_LOGIC;

        -- 2x 10 bit input signals that will be sent to the DAC. Output voltage
        -- levels are calculated as: Vout = 2.5 V * (k / 2^10)
        a, b : IN STD_LOGIC_VECTOR(9 DOWNTO 0);

        -- SPI interface to the DAC. Master-In Slave-Out (MISO) is not required.
        cs, mosi, clk : OUT STD_LOGIC
    );
END ENTITY dac;

ARCHITECTURE no_target_specific OF dac IS
BEGIN
END ARCHITECTURE no_target_specific;
