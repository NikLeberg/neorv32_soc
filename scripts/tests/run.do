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

# Gather all available vhdl source files. (This assumes the vhdl entities are
# organized in subfolders and have their testbenches in a tb subfolders.)
quietly set files [glob ../vhdl/*.vhdl ../vhdl/**/*.vhdl ../vhdl/**/tb/*.vhdl]

# List the entities in the order that they should be compiled. (This assumes
# entity file and entity itself have the same name.)
quietly set entities {
    "datatypes"

    "example"

    "keypad_reader"
    "keypad_debounce"
    "keypad_decoder"

    "number_input"
    "bcd_to_bin"
    "bin_to_bcd"
    
    "rpn"
}

# Compile the entity files.
foreach ent $entities {
    quietly set file [lsearch -inline -glob $files "*$ent.vhdl"]
    echo "Compiling entity $ent from file $file"
    vcom -quiet -pedanticerrors -check_synthesis -fsmverbose w -lint -source $file
}

# List the testbenches in the order that they should be compiled and executed.
# (This assumes testbench file and entity have the same name.)
quietly set testbenches {
    "example_tb"

    "keypad_reader_tb"
    "keypad_debounce_tb"
    "keypad_decoder_tb"
}

# Compile and run the testbenches.
foreach testbench $testbenches {
    quietly set file [lsearch -inline -glob $files "*/tb/$testbench.vhdl"]
    echo "--------------------------------"
    echo "Compiling testbench $testbench from file $file"
    vcom -quiet -2008 -pedanticerrors -check_synthesis -lint -source $file
    echo "Running testbench $testbench:"
    vsim -quiet -hazards -t ns -c $testbench
    run -all
}

# Quit
quit -f