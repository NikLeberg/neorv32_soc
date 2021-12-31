# run: "vsim -c -do ../scripts/tests/run.do" from ../modelsim folder

# Exit with code 1 on error
onerror {quit -code 1}

# Exit with code 1 on break (gets triggered on assertion failure)
onbreak {quit -code 1}

# Create work library.
if [file exists work] {
    vdel -all
}
vlib work

# Compile the entity files. Order matters!
quietly set files "example datatypes keypad_reader keypad_debounce keypad_decoder number_input bcd_to_bin bin_to_bcd rpn"
foreach file $files {
    echo "Compiling file ${file}.vhdl"
    vcom -quiet -pedanticerrors -check_synthesis -fsmverbose w -lint -source ../vhdl/${file}.vhdl
}

# Compile and run the testbenches. (Testbench file and entity need same name.)
quietly set testbenches "example_tb keypad_reader_tb keypad_debounce_tb keypad_decoder_tb"
foreach testbench $testbenches {
    echo "--------------------------------"
    echo "Compiling testbench file ${testbench}.vhdl"
    vcom -quiet -2008 -pedanticerrors -check_synthesis -lint -source ../vhdl/${testbench}.vhdl
    echo "Running testbench ${testbench}:"
    vsim -quiet -hazards -t ns -c $testbench
    run -all
}

# Quit
quit -f