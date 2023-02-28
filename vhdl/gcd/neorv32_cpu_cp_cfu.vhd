-- #################################################################################################
-- # << NEORV32 - CPU Co-Processor: Custom (Instructions) Functions Unit >>                        #
-- # ********************************************************************************************* #
-- # For user-defined custom RISC-V instructions (R3-type, R4-type and R5-type formats).           #
-- # See the CPU's documentation for more information.                                             #
-- #                                                                                               #
-- # NOTE: Take a look at the "software-counterpart" of this CFU example in 'sw/example/demo_cfu'. #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2023, Stephan Nolting. All rights reserved.                                     #
-- #                                                                                               #
-- # Redistribution and use in source and binary forms, with or without modification, are          #
-- # permitted provided that the following conditions are met:                                     #
-- #                                                                                               #
-- # 1. Redistributions of source code must retain the above copyright notice, this list of        #
-- #    conditions and the following disclaimer.                                                   #
-- #                                                                                               #
-- # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
-- #    conditions and the following disclaimer in the documentation and/or other materials        #
-- #    provided with the distribution.                                                            #
-- #                                                                                               #
-- # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
-- #    endorse or promote products derived from this software without specific prior written      #
-- #    permission.                                                                                #
-- #                                                                                               #
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
-- # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
-- # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
-- # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
-- # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
-- # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
-- # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
-- # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
-- # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
-- # ********************************************************************************************* #
-- # The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32       (c) Stephan Nolting #
-- #################################################################################################

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY neorv32;
USE neorv32.neorv32_package.ALL;

ENTITY neorv32_cpu_cp_cfu IS
  GENERIC (
    XLEN : NATURAL -- data path width
  );
  PORT (
    -- global control --
    clk_i   : IN STD_ULOGIC; -- global clock, rising edge
    rstn_i  : IN STD_ULOGIC; -- global reset, low-active, async
    ctrl_i  : IN ctrl_bus_t; -- main control bus
    start_i : IN STD_ULOGIC; -- trigger operation
    -- data input --
    rs1_i : IN STD_ULOGIC_VECTOR(XLEN - 1 DOWNTO 0); -- rf source 1
    rs2_i : IN STD_ULOGIC_VECTOR(XLEN - 1 DOWNTO 0); -- rf source 2
    rs3_i : IN STD_ULOGIC_VECTOR(XLEN - 1 DOWNTO 0); -- rf source 3
    rs4_i : IN STD_ULOGIC_VECTOR(XLEN - 1 DOWNTO 0); -- rf source 4
    -- result and status --
    res_o   : OUT STD_ULOGIC_VECTOR(XLEN - 1 DOWNTO 0); -- operation result
    valid_o : OUT STD_ULOGIC                            -- data output valid
  );
END neorv32_cpu_cp_cfu;

ARCHITECTURE neorv32_cpu_cp_cfu_rtl OF neorv32_cpu_cp_cfu IS

  -- CFU controll - do not modify! ---------------------------
  -- ------------------------------------------------------------

  TYPE control_t IS RECORD
    busy : STD_ULOGIC; -- CFU is busy
    done : STD_ULOGIC; -- set to '1' when processing is done
    result : STD_ULOGIC_VECTOR(XLEN - 1 DOWNTO 0); -- user's processing result (for write-back to register file)
    rtype : STD_ULOGIC_VECTOR(1 DOWNTO 0); -- instruction type, see constants below
    funct3 : STD_ULOGIC_VECTOR(2 DOWNTO 0); -- "funct3" bit-field from custom instruction
    funct7 : STD_ULOGIC_VECTOR(6 DOWNTO 0); -- "funct7" bit-field from custom instruction
  END RECORD;
  SIGNAL control : control_t;

  -- instruction format types --
  CONSTANT r3type_c : STD_ULOGIC_VECTOR(1 DOWNTO 0) := "00"; -- R3-type instructions (custom-0 opcode)
  CONSTANT r4type_c : STD_ULOGIC_VECTOR(1 DOWNTO 0) := "01"; -- R4-type instructions (custom-1 opcode)
  CONSTANT r5typeA_c : STD_ULOGIC_VECTOR(1 DOWNTO 0) := "10"; -- R5-type instruction A (custom-2 opcode)
  CONSTANT r5typeB_c : STD_ULOGIC_VECTOR(1 DOWNTO 0) := "11"; -- R5-type instruction B (custom-3 opcode)

  -- User Logic ----------------------------------------------
  -- ------------------------------------------------------------

  -- GCD Accelerator --
  COMPONENT gcd IS
    GENERIC (
      NBITS : POSITIVE := 32 -- width of data
    );
    PORT (
      clk    : IN STD_LOGIC := '0'; -- clock of the algorithm
      clk_en : IN STD_LOGIC := '0'; -- clock enable of the algorithm
      start  : IN STD_LOGIC := '0'; -- strobe to start the algorithm
      reset  : IN STD_LOGIC := '0'; -- reset of the algorithm

      dataa : IN UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0'); -- first input number
      datab : IN UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0'); -- second input number

      done  : OUT STD_LOGIC := '0'; -- strobe to signal that the algorithm is done
      ready : OUT STD_LOGIC := '1'; -- signal that the block is ready for a new calculation

      result : OUT UNSIGNED(NBITS - 1 DOWNTO 0) := (OTHERS => '0') -- calculated result
    );
  END COMPONENT gcd;

  SIGNAL gcd_reset : STD_ULOGIC;
  SIGNAL gcd_dataa, gcd_datab, gcd_result : UNSIGNED(XLEN - 1 DOWNTO 0) := (OTHERS => '0');

BEGIN

  -- ****************************************************************************************************************************
  -- This controller is required to handle the CPU/pipeline interface. Do not modify!
  -- ****************************************************************************************************************************

  -- CFU Controller -------------------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  cfu_control : PROCESS (rstn_i, clk_i)
  BEGIN
    IF (rstn_i = '0') THEN
      res_o <= (OTHERS => '0');
      control.busy <= '0';
    ELSIF rising_edge(clk_i) THEN
      res_o <= (OTHERS => '0'); -- default; all CPU co-processor outputs are logically OR-ed
      IF (control.busy = '0') THEN -- idle
        IF (start_i = '1') THEN
          control.busy <= '1';
        END IF;
      ELSE -- busy
        IF (control.done = '1') OR (ctrl_i.cpu_trap = '1') THEN -- processing done? abort if trap (exception)
          res_o <= control.result; -- output result for just one cycle, CFU output has to be all-zero otherwise
          control.busy <= '0';
        END IF;
      END IF;
    END IF;
  END PROCESS cfu_control;

  -- CPU feedback --
  valid_o <= control.busy AND control.done; -- set one cycle before result data

  -- pack user-defined instruction type/function bits --
  control.rtype <= ctrl_i.ir_opcode(6 DOWNTO 5);
  control.funct3 <= ctrl_i.ir_funct3;
  control.funct7 <= ctrl_i.ir_funct12(11 DOWNTO 5);

  -- ****************************************************************************************************************************
  -- CFU Hardware Documentation and Implementation Notes
  -- ****************************************************************************************************************************

  -- ----------------------------------------------------------------------------------------
  -- CFU Instruction Formats
  -- ----------------------------------------------------------------------------------------
  -- The CFU supports three instruction types:
  --
  -- Up to 1024 RISC-V R3-Type Instructions (RISC-V standard):
  -- This format consists of two source registers ('rs1', 'rs2'), a destination register ('rd') and two "immediate" bit-fields
  -- ('funct7' and 'funct3').
  --
  -- Up to 8 RISC-V R4-Type Instructions (RISC-V standard):
  -- This format consists of three source registers ('rs1', 'rs2', 'rs3'), a destination register ('rd') and one "immediate"
  -- bit-field ('funct7').
  --
  -- Two individual RISC-V R5-Type Instructions (NEORV32-specific):
  -- This format consists of four source registers ('rs1', 'rs2', 'rs3', 'rs4') and a destination register ('rd'). There are
  -- no immediate fields.
  -- ----------------------------------------------------------------------------------------
  -- Input Operands
  -- ----------------------------------------------------------------------------------------
  -- > rs1_i          (input, 32-bit): source register 1; selected by 'rs1' bit-field
  -- > rs2_i          (input, 32-bit): source register 2; selected by 'rs2' bit-field
  -- > rs3_i          (input, 32-bit): source register 3; selected by 'rs3' bit-field
  -- > rs4_i          (input, 32-bit): source register 4; selected by 'rs4' bit-field
  -- > control.rtype  (input,  2-bit): defining the R-type; driven by OPCODE
  -- > control.funct3 (input,  3-bit): 3-bit function select / immediate value; driven by instruction word's 'funct3' bit-field
  -- > control.funct7 (input,  7-bit): 7-bit function select / immediate value; driven by instruction word's 'funct7' bit-field
  --
  -- [NOTE] The set of usable signals depends on the actual R-type of the instruction.
  --
  -- The general instruction type is identified by the <control.rtype>.
  -- > r3type_c  - R3-type instructions (custom-0 opcode)
  -- > r4type_c  - R4-type instructions (custom-1 opcode)
  -- > r5typeA_c - R5-type instruction A (custom-2 opcode)
  -- > r5typeB_c - R5-type instruction B (custom-3 opcode)
  --
  -- The four signals <rs1_i>, <rs2_i>, <rs3_i> and <rs4_i> provide the source operand data read from the CPU's register file.
  -- The source registers are adressed by the custom instruction word's 'rs1', 'rs2', 'rs3' and 'rs4' bit-fields.
  --
  -- The actual CFU operation can be defined by using the <control.funct3> and/or <control.funct7> signals (if available for a
  -- certain R-type instruction). Both signals are directly driven by the according bit-fields of the custom instruction word.
  -- These immediates can be used to select the actual function or to provide small literals for certain operations (like shift
  -- amounts, offsets, multiplication factors, ...).
  --
  -- [NOTE] <rs1_i>, <rs2_i>, <rs3_i> and <rs4_i> are directly driven by the register file (e.g. block RAM). For complex CFU
  --        designs it is recommended to buffer these signals using CFU-internal registers before actually using them.
  --
  -- [NOTE] The R4-type instructions and R5-type instruction provide additional source register. When used, this will increase
  --        the hardware requirements of the register file.
  --
  -- [NOTE] The CFU cannot cause any kind of exception at all (yet; this feature is planned for the future).
  -- ----------------------------------------------------------------------------------------
  -- Result Output
  -- ----------------------------------------------------------------------------------------
  -- > control.result (output, 32-bit): processing result ("data")
  --
  -- When the CFU has completed computations, the data send via the <control.result> signal will be written to the CPU's register
  -- file. The destination register is addressed by the <rd> bit-field in the instruction word. The CFU result output is registered
  -- in the CFU controller (see above) - so do not worry too much about increasing the CPU's critical path with your custom
  -- logic.
  -- ----------------------------------------------------------------------------------------
  -- Processing Control
  -- ----------------------------------------------------------------------------------------
  -- > rstn_i       (input,  1-bit): asynchronous reset, low-active
  -- > clk_i        (input,  1-bit): main clock, triggering on rising edge
  -- > start_i      (input,  1-bit): operation trigger (start processing, high for one cycle)
  -- > control.done (output, 1-bit): set high when processing is done
  --
  -- For pure-combinatorial instructions (completing within 1 clock cycle) <control.done> can be tied to 1. If the CFU requires
  -- several clock cycles for internal processing, the <start_i> signal can be used to *start* a new iterative operation. As soon
  -- as all internal computations have completed, the <control.done> signal has to be set to indicate completion. This will
  -- complete CFU instruction operation and will also write the processing result <control.result> back to the CPU register file.
  --
  -- [NOTE] If the <control.done> signal is not set within a bound time window (default = 128 cycles) the CFU operation is
  --        automatically terminated by the hardware and an illegal instruction exception is raised. This feature can also be
  --        be used to implement custom CFU exceptions.
  -- ----------------------------------------------------------------------------------------
  -- Final Notes
  -- ----------------------------------------------------------------------------------------
  -- The <control> record provides something like a "keeper" that ensures correct functionality and that also provides a
  -- simple-to-use interface hardware designers can start with. However, the control instance adds one additional cycle of
  -- latency. Advanced users can remove this default control instance to obtain maximum throughput.

  -- ****************************************************************************************************************************
  -- Actual CFU User Logic Example - replace this with your custom logic
  -- ****************************************************************************************************************************

  -- Greatest Commond Divisor Accelerator ---------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  gcb_inst : gcd
  GENERIC MAP(
    NBITS => XLEN -- width of data
  )
  PORT MAP(
    clk    => clk_i,        -- clock of the algorithm
    clk_en => '1',          -- clock enable of the algorithm
    start  => start_i,      -- strobe to start the algorithm
    reset  => gcd_reset,    -- reset of the algorithm
    dataa  => gcd_dataa,    -- first input number
    datab  => gcd_datab,    -- second input number
    done   => control.done, -- strobe to signal that the algorithm is done
    ready  => OPEN,         -- signal that the block is ready for a new calculation
    result => gcd_result    -- calculated result
  );
  gcd_reset <= NOT rstn_i;
  gcd_dataa <= UNSIGNED(rs1_i);
  gcd_datab <= UNSIGNED(rs2_i);
  control.result <= STD_ULOGIC_VECTOR(gcd_result);

END neorv32_cpu_cp_cfu_rtl;
