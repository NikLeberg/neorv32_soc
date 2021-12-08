# run: "vsim -c -do ../scripts/tests/run.do" from ../modelsim folder

# Create work library.
if [file exists work] {
    vdel -all
}
vlib work

# Compile the sources. Order matters!
set files "example.vhdl"
foreach file $files {
    vcom -pedanticerrors -check_synthesis -fsmverbose w -lint -source ../vhdl/$file
}

# Simulate
#vsim -c test
#run -all
quit -f