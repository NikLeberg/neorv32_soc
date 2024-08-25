-- =============================================================================
-- File:                    wbp_pkg.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.1
--
-- Entity:                  wbp_pkg
--
-- Description:             Package with type and function definitions for
--                          pipelined Wishbone interconnect. See:
--                          https://cdn.opencores.org/downloads/wbspec_b4.pdf
--
-- Changes:                 0.1, 2024-08-19, leuen4
--                              initial version
-- =============================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

PACKAGE wbp_pkg IS
  -- Width of address bus
  CONSTANT WBP_ADDRESS_WIDTH : NATURAL := 32;
  -- Width of data bus
  CONSTANT WBP_DATA_WIDTH : NATURAL := 32;

  -- Number of bytes in data bus
  CONSTANT WBP_NUM_BYTES : NATURAL := WBP_DATA_WIDTH / 8;

  -- Intercon memory map entry type
  TYPE wbp_map_entry_t IS RECORD
    BASE_ADDRESS : STD_ULOGIC_VECTOR(WBP_ADDRESS_WIDTH - 1 DOWNTO 0); -- base address of slave address range
    SIZE : NATURAL; -- size of slave address range in bytes
  END RECORD wbp_map_entry_t;
  -- Intercon memory map type
  TYPE wbp_map_t IS ARRAY (NATURAL RANGE <>) OF wbp_map_entry_t;

  -- Wishbone request type (aka master out, slave in)
  TYPE wbp_mosi_sig_t IS RECORD
    adr : STD_ULOGIC_VECTOR(WBP_ADDRESS_WIDTH - 1 DOWNTO 0); -- address
    dat : STD_ULOGIC_VECTOR(WBP_DATA_WIDTH - 1 DOWNTO 0); -- write data
    we : STD_ULOGIC; -- read = '0' / write = '1'
    sel : STD_ULOGIC_VECTOR(WBP_NUM_BYTES - 1 DOWNTO 0); -- byte enable
    stb : STD_ULOGIC; -- strobe
    cyc : STD_ULOGIC; -- valid cycle
  END RECORD wbp_mosi_sig_t;

  -- Wishbone response type (aka master in, slave out)
  TYPE wbp_miso_sig_t IS RECORD
    stall : STD_ULOGIC; -- slave busy
    ack : STD_ULOGIC; -- transfer acknowledge
    err : STD_ULOGIC; -- transfer error
    dat : STD_ULOGIC_VECTOR(WBP_DATA_WIDTH - 1 DOWNTO 0); -- read data
  END RECORD wbp_miso_sig_t;

  -- Wishbone interface array types
  TYPE wbp_mosi_arr_t IS ARRAY (NATURAL RANGE <>) OF wbp_mosi_sig_t;
  TYPE wbp_miso_arr_t IS ARRAY (NATURAL RANGE <>) OF wbp_miso_sig_t;

  -- Return ceiled log2 of integer numbers i.e. log2(32) = 5, log2(33) = 6.
  FUNCTION log2(CONSTANT n : NATURAL) RETURN NATURAL;

  -- Function to calculate the MSB bit position of the address that addresses
  -- the data inside the slave based on the data space given in the memory
  -- map. E.g. slave with 4 * 32 bits of data uses 16 addresses and as such
  -- func returns 4 LSB bits. Address WBP_ADDRESS_WIDTH downto 4 addresses the
  -- slave itself and 3 downto 0 addresses individual memory in the slave. 
  FUNCTION wbp_get_slave_address_range (CONSTANT entry : wbp_map_entry_t) RETURN NATURAL;

END PACKAGE wbp_pkg;

PACKAGE BODY wbp_pkg IS
  FUNCTION log2(
    CONSTANT n : NATURAL
  ) RETURN NATURAL IS
  BEGIN
    RETURN NATURAL(ceil(log2(real(n))));
  END log2;

  FUNCTION wbp_get_slave_address_range (
    CONSTANT entry : wbp_map_entry_t
  ) RETURN NATURAL IS
  BEGIN
    RETURN log2(entry.SIZE);
  END FUNCTION;
END PACKAGE BODY wbp_pkg;
