-------------------------------------------------------------------------------
-- Title      : Testbench for design "gcd"
-- Project    : BTE5380
-------------------------------------------------------------------------------
-- File       : gcd_tb.vhdl
-- Author     : Torsten Maehne  <torsten.maehne@bfh.ch>
-- Company    : BFH-EIT
-- Created    : 2020-01-05
-- Last update: 2020-01-06
-- Platform   : Intel Quartus Prime 18.1
-- Standard   : VHDL'93/02, Math Packages
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2020 BFH-EIT
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-01-05  1.0      mht1	Created
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

-------------------------------------------------------------------------------

ENTITY gcd_tb IS

END ENTITY gcd_tb;

-------------------------------------------------------------------------------

ARCHITECTURE bench OF gcd_tb IS
  -- stimuli generics
  CONSTANT CLK_PERIOD : delay_length := 10 ns;
  -- component generics
  CONSTANT NBITS : POSITIVE := 32;

  -- component ports
  SIGNAL clk : STD_LOGIC := '1';
  SIGNAL clk_en : STD_LOGIC := '1';
  SIGNAL reset : STD_LOGIC;
  SIGNAL dataa, datab : unsigned(NBITS - 1 DOWNTO 0);
  SIGNAL start : STD_LOGIC;
  SIGNAL done : STD_LOGIC;
  SIGNAL ready : STD_LOGIC;
  SIGNAL result : unsigned(NBITS - 1 DOWNTO 0);

  -- internal signals
  SIGNAL tb_finished : BOOLEAN := false; -- flag end of tests

BEGIN -- architecture bench

  -- component instantiation
  DUT : ENTITY work.gcd
    GENERIC MAP(
      NBITS => NBITS)
    PORT MAP(
      clk    => clk,
      clk_en => clk_en,
      reset  => reset,
      dataa  => dataa,
      datab  => datab,
      start  => start,
      ready  => ready,
      done   => done,
      result => result);

  -- clock and reset generation
  clk <= NOT clk AFTER 0.5 * CLK_PERIOD WHEN NOT tb_finished;
  reset <= '0', '1' AFTER 0.25 * CLK_PERIOD, '0' AFTER 0.75 * CLK_PERIOD;

  -- waveform generation
  STIMULI : PROCESS
    -- purpose: test GCD calculation with provided arguments
    PROCEDURE do_test (
      CONSTANT a_in, b_in : IN NATURAL;    -- arguments for gcd operation
      CONSTANT r_exp      : IN NATURAL) IS -- expected result
      -- maximum tolerated time for GCD operation to last
      CONSTANT OP_MAX_TIME : delay_length := 10 * NBITS * CLK_PERIOD;
    BEGIN -- procedure do_test
      ASSERT NBITS <= 32
      REPORT "Implementation of do_test relies on natural data type, which is limited to 32 bit."
        SEVERITY failure;
      dataa <= to_unsigned(a_in, dataa'length);
      datab <= to_unsigned(b_in, datab'length);
      start <= '1';
      WAIT UNTIL clk = '1';
      start <= '0';
      ASSERT done = '0'
      REPORT "DUT not busy as expected!"
        SEVERITY error;
      WAIT UNTIL done = '1' FOR OP_MAX_TIME;
      WAIT UNTIL clk = '1';
      dataa <= (OTHERS => '-');
      datab <= (OTHERS => '-');
      ASSERT done = '1'
      REPORT "GCD calculation timeout!"
        SEVERITY error;
      ASSERT result = r_exp
      REPORT "Calculation error: gcd(" &
        INTEGER'image(a_in) & ", " & INTEGER'image(b_in) & ") = " &
        INTEGER'image(to_integer(result)) &
        " (expected: " & INTEGER'image(r_exp) & ")"
        SEVERITY error;
    END PROCEDURE do_test;
  BEGIN
    -- insert signal assignments here
    WAIT UNTIL reset = '1';
    dataa <= (OTHERS => '-');
    datab <= (OTHERS => '-');
    start <= '0';
    WAIT UNTIL reset = '0';
    WAIT UNTIL clk = '1';
    do_test(a_in => 9, b_in => 12, r_exp => 3);
    do_test(a_in => 12, b_in => 6, r_exp => 6);
    do_test(a_in => 4, b_in => 3, r_exp => 1);
    do_test(a_in => 13, b_in => 13, r_exp => 13);
    do_test(a_in => 0, b_in => 0, r_exp => 0);
    do_test(a_in => 294, b_in => 546, r_exp => 42);
    do_test(a_in => 546, b_in => 294, r_exp => 42);
    do_test(a_in => 363710, b_in => 897335, r_exp => 5);
    WAIT UNTIL clk = '1';
    tb_finished <= true;
  END PROCESS STIMULI;

END ARCHITECTURE bench;

-------------------------------------------------------------------------------
