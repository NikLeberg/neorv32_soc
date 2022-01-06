# Exit with code 1 on error
onerror {quit -code 1}

# Exit with code 1 on break
onbreak {quit -code 1}

# Create work library.
if [file exists work] {
    vdel -all
}
vlib work

# Get definitions of files and entities.
quietly source ../scripts/files.tcl

# Compile the entity files.
foreach ent $entities {
    quietly set file [lsearch -inline -glob $files "*$ent.vhdl"]
    echo "Compiling entity $ent from file $file"
    vcom -quiet -pedanticerrors -check_synthesis -fsmverbose w -lint $file
}

# Compile the testbench files.
foreach testbench $testbenches {
    quietly set file [lsearch -inline -glob $files "*/tb/$testbench.vhdl"]
    echo "Compiling testbench $testbench from file $file"
    vcom -quiet -2008 -pedanticerrors -check_synthesis -lint $file
}

quit -f
