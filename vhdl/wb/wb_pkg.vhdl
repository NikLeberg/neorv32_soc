-- =============================================================================
-- File:                    wb_pkg.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  wb_pkg
--
-- Description:             Package with type and function definitions for
--                          Wishbone interconnect.
--
-- Changes:                 0.1, 2023-02-26, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

PACKAGE wb_pkg IS
    -- Width of address bus
    CONSTANT WB_ADDRESS_WIDTH : NATURAL := 32;
    -- Width of data bus
    CONSTANT WB_DATA_WIDTH : NATURAL := 32;

    -- Number of bytes in data bus
    CONSTANT WB_NUM_BYTES : NATURAL := WB_DATA_WIDTH / 8;

    -- Intercon memory map entry type
    TYPE wb_map_entry_t IS RECORD
        BASE_ADDRESS : STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0); -- base address of slave address range
        SIZE : NATURAL; -- size of slave address range in bytes
    END RECORD wb_map_entry_t;
    -- Intercon memory map type
    TYPE wb_map_t IS ARRAY (NATURAL RANGE <>) OF wb_map_entry_t;

    -- Wishbone master output interface type
    TYPE wb_master_tx_sig_t IS RECORD
        adr : STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0); -- address
        dat : STD_ULOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0); -- write data
        we : STD_ULOGIC; -- read = '0' / write = '1'
        sel : STD_ULOGIC_VECTOR(WB_NUM_BYTES - 1 DOWNTO 0); -- byte enable
        stb : STD_ULOGIC; -- strobe
        cyc : STD_ULOGIC; -- valid cycle
    END RECORD wb_master_tx_sig_t;

    -- Wishbone master input interface type
    TYPE wb_master_rx_sig_t IS RECORD
        ack : STD_ULOGIC; -- transfer acknowledge
        err : STD_ULOGIC; -- transfer error
        dat : STD_ULOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0); -- read data
    END RECORD wb_master_rx_sig_t;

    -- Wishbone slave input and output interface type
    SUBTYPE wb_slave_rx_sig_t IS wb_master_tx_sig_t;
    SUBTYPE wb_slave_tx_sig_t IS wb_master_rx_sig_t;

    -- Wishbone slave interface array types
    TYPE wb_slave_rx_arr_t IS ARRAY (NATURAL RANGE <>) OF wb_slave_rx_sig_t;
    TYPE wb_slave_tx_arr_t IS ARRAY (NATURAL RANGE <>) OF wb_slave_tx_sig_t;

    -- Array of natural type
    TYPE natural_arr_t IS ARRAY (NATURAL RANGE <>) OF NATURAL;

    -- Function to calculate the number of MSB bits in the address that are
    -- uniquely owned by the slave based on the memory map with the base address
    -- of each slave and its data space size.
    FUNCTION wb_calc_coarse_decode_bit_nums (memory_map : wb_map_t) RETURN natural_arr_t;

    -- Function to calculate the MSB bit numbers of the address that are
    -- uniquely owned by the slave based on the memory map with the base address
    -- of each slave and its data space size.
    FUNCTION wb_calc_coarse_decode_msb_bit_nums (memory_map : wb_map_t) RETURN natural_arr_t;

END PACKAGE wb_pkg;

PACKAGE BODY wb_pkg IS
    FUNCTION wb_calc_coarse_decode_bit_nums (memory_map : wb_map_t) RETURN natural_arr_t IS
        VARIABLE coarse_decode_bit_nums : natural_arr_t(memory_map'length - 1 DOWNTO 0);
    BEGIN
        FOR i IN memory_map'length - 1 DOWNTO 0 LOOP
            coarse_decode_bit_nums(i) := WB_ADDRESS_WIDTH - INTEGER(ceil(log2(real(memory_map(i).SIZE))));
        END LOOP;
        RETURN coarse_decode_bit_nums;
    END FUNCTION;

    FUNCTION wb_calc_coarse_decode_msb_bit_nums (memory_map : wb_map_t) RETURN natural_arr_t IS
        VARIABLE coarse_decode_msb_bit_nums : natural_arr_t(memory_map'length - 1 DOWNTO 0);
    BEGIN
        FOR i IN memory_map'length - 1 DOWNTO 0 LOOP
            coarse_decode_msb_bit_nums(i) := INTEGER(ceil(log2(real(memory_map(i).SIZE))));
        END LOOP;
        RETURN coarse_decode_msb_bit_nums;
    END FUNCTION;

END PACKAGE BODY wb_pkg;
