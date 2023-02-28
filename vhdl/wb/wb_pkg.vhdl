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

    -- Procedure to simulate read transaction on Wishbone bus. 
    PROCEDURE wb_sim_read32 (
        SIGNAL clk          : IN STD_ULOGIC;                                       -- global clock, rising edge
        SIGNAL wb_master_tx : OUT wb_master_tx_sig_t;                              -- master out, slave in
        SIGNAL wb_master_rx : IN wb_master_rx_sig_t;                               -- slave out, master in
        CONSTANT address    : IN STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0); -- address to read from
        CONSTANT data       : IN STD_ULOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0)     -- expected data
    );

    -- Procedure to simulate write transaction on Wishbone bus. 
    PROCEDURE wb_sim_write32 (
        SIGNAL clk          : IN STD_ULOGIC;                                       -- global clock, rising edge
        SIGNAL wb_master_tx : OUT wb_master_tx_sig_t;                              -- master out, slave in
        SIGNAL wb_master_rx : IN wb_master_rx_sig_t;                               -- slave out, master in
        CONSTANT address    : IN STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0); -- address to write to
        CONSTANT data       : IN STD_ULOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0)     -- data to write
    );

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

    PROCEDURE wb_sim_read32 (
        SIGNAL clk          : IN STD_ULOGIC;                                       -- global clock, rising edge
        SIGNAL wb_master_tx : OUT wb_master_tx_sig_t;                              -- master out, slave in
        SIGNAL wb_master_rx : IN wb_master_rx_sig_t;                               -- slave out, master in
        CONSTANT address    : IN STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0); -- address to read from
        CONSTANT data       : IN STD_ULOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0)     -- expected data
    ) IS
    BEGIN
        ASSERT WB_DATA_WIDTH >= 32
        REPORT "Wishbone sim parameter error: Can't read 32 bit data word on architecture with only " & NATURAL'image(WB_DATA_WIDTH) & " bits."
            SEVERITY error;
        ASSERT address(1 DOWNTO 0) = "00"
        REPORT "Wishbone sim parameter error: Can't read unaligned 32 bit data word."
            SEVERITY error;
        -- sync to rising edge of clock
        WAIT UNTIL rising_edge(clk);
        -- set wishbone bus signals
        wb_master_tx.we <= '0';
        wb_master_tx.adr <= address;
        wb_master_tx.dat <= (OTHERS => 'X'); -- no data to send
        wb_master_tx.sel(3 DOWNTO 0) <= (OTHERS => '1'); -- full word, 32 bits
        wb_master_tx.sel(WB_NUM_BYTES - 1 DOWNTO 4) <= (OTHERS => '0');
        -- start transaction and wait for ack or err
        wb_master_tx.cyc <= '1';
        wb_master_tx.stb <= '1';
        WHILE wb_master_rx.ack = '0' AND wb_master_rx.err = '0' LOOP
            WAIT UNTIL rising_edge(clk);
        END LOOP;
        -- end transaction
        wb_master_tx.cyc <= '0';
        wb_master_tx.stb <= '0';
        -- check response
        ASSERT wb_master_rx.err = '0'
        REPORT "Wishbone sim read failure: Slave did respond with ERR."
            SEVERITY failure;
        ASSERT wb_master_rx.ack = '1'
        REPORT "Wishbone sim read failure: Slave did not ACK."
            SEVERITY failure;
        REPORT INTEGER'image(to_integer(UNSIGNED(wb_master_rx.dat)));
        ASSERT wb_master_rx.dat = data
        REPORT "Wishbone sim read failure: Slave did send unexpected data."
            SEVERITY failure;
    END PROCEDURE;

    PROCEDURE wb_sim_write32 (
        SIGNAL clk          : IN STD_ULOGIC;                                       -- global clock, rising edge
        SIGNAL wb_master_tx : OUT wb_master_tx_sig_t;                              -- master out, slave in
        SIGNAL wb_master_rx : IN wb_master_rx_sig_t;                               -- slave out, master in
        CONSTANT address    : IN STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0); -- address to write to
        CONSTANT data       : IN STD_ULOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0)     -- data to write
    ) IS
    BEGIN
        ASSERT WB_DATA_WIDTH >= 32
        REPORT "Wishbone sim parameter error: Can't read 32 bit data word on architecture with only " & NATURAL'image(WB_DATA_WIDTH) & " bits."
            SEVERITY error;
        ASSERT address(1 DOWNTO 0) = "00"
        REPORT "Wishbone sim parameter error: Can't write unaligned 32 bit data word."
            SEVERITY error;
        -- sync to rising edge of clock
        WAIT UNTIL rising_edge(clk);
        -- set wishbone bus signals
        wb_master_tx.we <= '1';
        wb_master_tx.adr <= address;
        wb_master_tx.dat <= data;
        wb_master_tx.sel(3 DOWNTO 0) <= (OTHERS => '1'); -- full word, 32 bits
        wb_master_tx.sel(WB_NUM_BYTES - 1 DOWNTO 4) <= (OTHERS => '0');
        -- start transaction and wait for ack or err
        wb_master_tx.cyc <= '1';
        wb_master_tx.stb <= '1';
        WHILE wb_master_rx.ack = '0' AND wb_master_rx.err = '0' LOOP
            WAIT UNTIL rising_edge(clk);
        END LOOP;
        -- end transaction
        wb_master_tx.cyc <= '0';
        wb_master_tx.stb <= '0';
        -- check response
        ASSERT wb_master_rx.err = '0'
        REPORT "Wishbone sim write failure: Slave did respond with ERR."
            SEVERITY failure;
        ASSERT wb_master_rx.ack = '1'
        REPORT "Wishbone sim read failure: Slave did not ACK."
            SEVERITY failure;
    END PROCEDURE;

END PACKAGE BODY wb_pkg;
