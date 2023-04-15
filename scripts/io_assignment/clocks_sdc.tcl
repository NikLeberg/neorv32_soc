#**************************************************************
# Time Information
#**************************************************************
set_time_format -unit ns -decimal_places 3

#**************************************************************
# Create Clock
#**************************************************************
create_clock -name {clk_i} -period 20.000 -waveform { 0.000 10.000 } [get_ports {clk_i}]
create_clock -name {altera_reserved_tck} -period 100.000 -waveform { 0.000 50.000 } [get_ports {altera_reserved_tck}]

#**************************************************************
# Create Generated Clock
#**************************************************************
#create_generated_clock -name {pll_inst|altpll_component|auto_generated|pll1|clk[0]} -source [get_pins {pll_inst|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50/1 -multiply_by 2 -divide_by 1 -master_clock {clk_i} [get_pins {pll_inst|altpll_component|auto_generated|pll1|clk[0]}] 

#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty -add
