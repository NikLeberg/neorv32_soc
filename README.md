# neorv32_soc
Playing around with the [`neorv32`](https://github.com/stnolting/neorv32) SoC on a [Gecko4Education](https://gecko-wiki.ti.bfh.ch/gecko4education:start) Board with an Intel Cyclone IV E FPGA.

Initially I have used this project to recreate a greatest-common-denomitator accelerator as was teached in class. In class we used the NIOS II from Intel / Altera. This project then ported this over to the `neorv32` which is a RISC-V cpu architecture.
Afterwards the project took a turn and I'm now focusing it on symmetric multiprocessing aka SMP and have the goal to implement a SMP system based on the `neorv32`. As such the relevant GCD parts were moved or changed. But remnants of the VHDL hardware descriptions can be found in `vhdl/gcd` and for the software in `sw/gcd`. A working state of the GCD system would be in git commit [`774e708a13`](https://github.com/NikLeberg/neorv32_soc/tree/774e708a136450cfc5711121ee71b399df16a843).

## Project structure
```bash
.
├───sim     # ModelSim / QuestaSim workdir, files are generated with scripts/sim_*.tcl scripts.
├───quartus # Quartus workdir, files are generated with scripts/quartus_*.tcl scripts.
├───scripts # Tcl skripts to generate and manage project files.
├───vhdl    # VHDL RTL descriptions of project entities and toplevel.
└───lib     # Libraries as git submodules of the NEORV32 and other RTL entities.
```

## Simulation
Simulation of the different entities or modules and their corresponding testbenches can be done with the following commands. The commands have to be issued in a cli within `sim` working directory.

1. Compile:
```bash
vsim -c -do ../scripts/sim_compile.tcl
```

2. Running the testbenches:
```bash
vsim -c -do ../scripts/sim_test.tcl
```

- (optional) View signal waves of testbench (opens ModelSim or QuestaSim GUI):
```bash
vsim -c -do ../scripts/sim_open.tcl <name_of_testbench>
```

## Synthesis
Synthesis of the project with quartus can be done with the following commands. Run it in the `quartus` subfolder.

1. Generate the quartus project:
```bash
quartus_sh -t ../scripts/quartus_project.tcl
```

2. Synthesis:
```bash
quartus_sh -t ../scripts/quartus_compile.tcl
```

3. Load the bitstream onto the GECKO-Board:
```bash
quartus_pgm -c USB-Blaster --mode jtag --operation='p;top.sof'
```

- (optional) Flash the bitstream onto the GECKO-Board:
```bash
quartus_cpf -c ../../scripts/quartus_flash.cof
quartus_pgm ../../scripts/quartus_flash.cdf
```

- (optional) Open the Quartus GUI:
```bash
quartus top.qpf
```

## License
[MIT](LICENSE) © [Niklaus Leuenberger](https://github.com/NikLeberg).
