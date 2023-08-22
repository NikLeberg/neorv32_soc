-- =============================================================================
-- File:                    wb_pkg.vhdl
--
-- Authors:                 Niklaus Leuenberger <leuen4@bfh.ch>
--
-- Version:                 0.4
--
-- Entity:                  wb_pkg
--
-- Description:             Package with type and function definitions for
--                          Wishbone interconnect.
--
-- Changes:                 0.1, 2023-02-26, leuen4
--                              initial version
--                          0.2, 2023-08-03, leuen4
--                              extended wb_sim_read32 procedure with expect_err
--                              parameter to allow testing a failing read
--                          0.3, 2023-08-22, leuen4
--                              change from master and slave types to simple
--                              request and response types
--                          0.4, 2023-08-22, leuen4
--                              print read response and write request as note
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

    -- Wishbone request type (aka master out, slave in)
    TYPE wb_req_sig_t IS RECORD
        adr : STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0); -- address
        dat : STD_ULOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0); -- write data
        we : STD_ULOGIC; -- read = '0' / write = '1'
        sel : STD_ULOGIC_VECTOR(WB_NUM_BYTES - 1 DOWNTO 0); -- byte enable
        stb : STD_ULOGIC; -- strobe
        cyc : STD_ULOGIC; -- valid cycle
    END RECORD wb_req_sig_t;

    -- Wishbone response type (aka master in, slave out)
    TYPE wb_resp_sig_t IS RECORD
        ack : STD_ULOGIC; -- transfer acknowledge
        err : STD_ULOGIC; -- transfer error
        dat : STD_ULOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0); -- read data
    END RECORD wb_resp_sig_t;

    -- Wishbone interface array types
    TYPE wb_req_arr_t IS ARRAY (NATURAL RANGE <>) OF wb_req_sig_t;
    TYPE wb_resp_arr_t IS ARRAY (NATURAL RANGE <>) OF wb_resp_sig_t;

    -- Array of natural type
    TYPE natural_arr_t IS ARRAY (NATURAL RANGE <>) OF NATURAL;

    -- Function to calculate the MSB bit position of the address that addresses
    -- the data inside the slave based on the data space given in the memory
    -- map. E.g. slave with 4 * 32 bits of data uses 16 addresses and as such
    -- func returns 4 LSB bits. Address WB_ADDRESS_WIDTH downto 4 addresses the
    -- slave itself and 3 downto 0 addresses individual memory in the slave. 
    FUNCTION wb_get_slave_address_ranges (memory_map : wb_map_t) RETURN natural_arr_t;

    -- Procedure to simulate read transaction on Wishbone bus. 
    PROCEDURE wb_sim_read32 (
        SIGNAL clk          : IN STD_ULOGIC;                                       -- global clock, rising edge
        SIGNAL wb_req       : OUT wb_req_sig_t;                                    -- master out, slave in
        SIGNAL wb_resp      : IN wb_resp_sig_t;                                    -- slave out, master in
        CONSTANT address    : IN STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0); -- address to read from
        CONSTANT data       : IN STD_ULOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0);    -- expected data
        CONSTANT expect_err : IN BOOLEAN := FALSE                                  -- true: expect read to fail
    );

    -- Procedure to simulate write transaction on Wishbone bus. 
    PROCEDURE wb_sim_write32 (
        SIGNAL clk       : IN STD_ULOGIC;                                       -- global clock, rising edge
        SIGNAL wb_req    : OUT wb_req_sig_t;                                    -- master out, slave in
        SIGNAL wb_resp   : IN wb_resp_sig_t;                                    -- slave out, master in
        CONSTANT address : IN STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0); -- address to write to
        CONSTANT data    : IN STD_ULOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0)     -- data to write
    );

END PACKAGE wb_pkg;

PACKAGE BODY wb_pkg IS
    FUNCTION wb_get_slave_address_ranges (memory_map : wb_map_t) RETURN natural_arr_t IS
        VARIABLE address_ranges : natural_arr_t(memory_map'length - 1 DOWNTO 0);
    BEGIN
        FOR i IN memory_map'length - 1 DOWNTO 0 LOOP
            address_ranges(i) := INTEGER(ceil(log2(real(memory_map(i).SIZE))));
        END LOOP;
        RETURN address_ranges;
    END FUNCTION;

    PROCEDURE wb_sim_read32 (
        SIGNAL clk          : IN STD_ULOGIC;                                       -- global clock, rising edge
        SIGNAL wb_req       : OUT wb_req_sig_t;                                    -- master out, slave in
        SIGNAL wb_resp      : IN wb_resp_sig_t;                                    -- slave out, master in
        CONSTANT address    : IN STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0); -- address to read from
        CONSTANT data       : IN STD_ULOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0);    -- expected data
        CONSTANT expect_err : IN BOOLEAN := FALSE                                  -- true: expect read to fail
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
        wb_req.we <= '0';
        wb_req.adr <= address;
        wb_req.dat <= (OTHERS => 'X'); -- no data to send
        wb_req.sel(3 DOWNTO 0) <= (OTHERS => '1'); -- full word, 32 bits
        wb_req.sel(WB_NUM_BYTES - 1 DOWNTO 4) <= (OTHERS => '0');
        -- start transaction and wait for ack or err
        wb_req.cyc <= '1';
        wb_req.stb <= '1';
        WAIT UNTIL rising_edge(clk); -- strobe for at least one clock
        WHILE wb_resp.ack = '0' AND wb_resp.err = '0' LOOP
            WAIT UNTIL rising_edge(clk);
        END LOOP;
        -- end transaction
        wb_req.cyc <= '0';
        wb_req.stb <= '0';
        -- print response
        REPORT "wb read: [0x" & to_hstring(wb_req.adr) & "] => 0x" & to_hstring(wb_resp.dat)
            SEVERITY note;
        -- check response
        ASSERT (wb_resp.err = '0' OR expect_err)
        REPORT "Wishbone sim read failure: Slave did respond with ERR."
            SEVERITY failure;
        ASSERT (wb_resp.err = '1' OR NOT expect_err)
        REPORT "Wishbone sim read failure: Slave did NOT respond with ERR."
            SEVERITY failure;
        ASSERT (wb_resp.ack = '1' OR expect_err)
        REPORT "Wishbone sim read failure: Slave did not ACK."
            SEVERITY failure;
        ASSERT wb_resp.dat = data
        REPORT "Wishbone sim read failure: Slave did send unexpected data."
            SEVERITY failure;
    END PROCEDURE;

    PROCEDURE wb_sim_write32 (
        SIGNAL clk       : IN STD_ULOGIC;                                       -- global clock, rising edge
        SIGNAL wb_req    : OUT wb_req_sig_t;                                    -- master out, slave in
        SIGNAL wb_resp   : IN wb_resp_sig_t;                                    -- slave out, master in
        CONSTANT address : IN STD_ULOGIC_VECTOR(WB_ADDRESS_WIDTH - 1 DOWNTO 0); -- address to write to
        CONSTANT data    : IN STD_ULOGIC_VECTOR(WB_DATA_WIDTH - 1 DOWNTO 0)     -- data to write
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
        wb_req.we <= '1';
        wb_req.adr <= address;
        wb_req.dat <= data;
        wb_req.sel(3 DOWNTO 0) <= (OTHERS => '1'); -- full word, 32 bits
        wb_req.sel(WB_NUM_BYTES - 1 DOWNTO 4) <= (OTHERS => '0');
        -- start transaction and wait for ack or err
        wb_req.cyc <= '1';
        wb_req.stb <= '1';
        WAIT UNTIL rising_edge(clk); -- strobe for at least one clock
        WHILE wb_resp.ack = '0' AND wb_resp.err = '0' LOOP
            WAIT UNTIL rising_edge(clk);
        END LOOP;
        -- end transaction
        wb_req.cyc <= '0';
        wb_req.stb <= '0';
        -- print request
        REPORT "wb write: [0x" & to_hstring(wb_req.adr) & "] <= 0x" & to_hstring(wb_req.dat)
            SEVERITY note;
        -- check response
        ASSERT wb_resp.err = '0'
        REPORT "Wishbone sim write failure: Slave did respond with ERR."
            SEVERITY failure;
        ASSERT wb_resp.ack = '1'
        REPORT "Wishbone sim write failure: Slave did not ACK."
            SEVERITY failure;
    END PROCEDURE;

END PACKAGE BODY wb_pkg;
