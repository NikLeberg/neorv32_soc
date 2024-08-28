-- =============================================================================
-- File:                    neorv32_wbp_gpio.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  neorv32_wbp_gpio
--
-- Description:             Wishbone wrapper for neorv32_gpio. Instead of
--                          accessing it through the neorv32 specific internal
--                          bus, this wraps it in Wishbone. Reason being to
--                          allow routing to this gpio through an external
--                          Wishbone interconnect (e.g. xbar).
--
-- Changes:                 0.1, 2024-08-24, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

USE work.wbp_pkg.ALL;

ENTITY neorv32_wbp_gpio IS
    GENERIC (
        GPIO_NUM : NATURAL -- number of GPIO input/output pairs (0..64)
    );
    PORT (
        -- Global control --
        clk_i  : IN STD_ULOGIC; -- global clock, rising edge
        rstn_i : IN STD_ULOGIC; -- global reset, low-active, sync

        -- Wishbone slave interface --
        wbp_mosi : IN wbp_mosi_sig_t;  -- control and data from master to slave
        wbp_miso : OUT wbp_miso_sig_t; -- status and data from slave to master

        -- parallel io --
        gpio_o : OUT STD_ULOGIC_VECTOR(63 DOWNTO 0);
        gpio_i : IN STD_ULOGIC_VECTOR(63 DOWNTO 0)
    );
END ENTITY neorv32_wbp_gpio;

ARCHITECTURE no_target_specific OF neorv32_wbp_gpio IS

    -- Signals of the neorv32 cpu internal bus.
    SIGNAL req : bus_req_t;
    SIGNAL rsp : bus_rsp_t;

BEGIN

    -- Map Wishbone signals to neorv32 internal bus.
    req.stb <= wbp_mosi.stb;
    req.rw <= wbp_mosi.we;
    req.addr <= wbp_mosi.adr;
    req.data <= wbp_mosi.dat;
    wbp_miso.dat <= rsp.data;
    wbp_miso.ack <= rsp.ack;
    wbp_miso.stall <= '0'; -- never stalls
    wbp_miso.err <= '0'; -- no error possible

    -- NEORV32 GPIO instance ------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    neorv32_gpio_inst : ENTITY neorv32.neorv32_gpio
        GENERIC MAP(
            GPIO_NUM => GPIO_NUM -- number of GPIO input/output pairs (0..64)
        )
        PORT MAP(
            -- host access --
            clk_i     => clk_i,  -- global clock line
            rstn_i    => rstn_i, -- global reset line, low-active, async
            bus_req_i => req,    -- bus request
            bus_rsp_o => rsp,    -- bus response
            -- parallel io --
            gpio_o => gpio_o,
            gpio_i => gpio_i
        );

END ARCHITECTURE no_target_specific;
