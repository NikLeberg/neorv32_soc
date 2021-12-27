# run: "vsim -c -do ../scripts/tests/run.do" from ../modelsim folder

# Exit with code 1 on error
onerror {quit -code 1}

# Create work library.
if [file exists work] {
    vdel -all
}
vlib work

# Compile the entity files. Order matters!
set files "example datatypes keypad_reader keypad_decoder number_input bcd_to_bin bin_to_bcd rpn"
foreach file $files {
    echo --------------------------------
    vcom -pedanticerrors -check_synthesis -fsmverbose w -lint -source ../vhdl/${file}.vhdl
}

# Compile and run the testbenches. (Testbench file and entity need same name.)
set testbenches "example_tb keypad_reader_tb keypad_decoder_tb"
foreach testbench $testbenches {
    echo --------------------------------
    vcom -2008 -pedanticerrors -check_synthesis -lint -source ../vhdl/${testbench}.vhdl
    vsim -c $testbench
    run -all
}

# Quit
quit -f