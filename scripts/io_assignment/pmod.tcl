# You have to replace <ENTITY_PORT_NAME_xxx> with the name of the PMOD I/O port
# of your top entity
set_location_assignment PIN_F2 -to vga_red_o[3]
set_location_assignment PIN_E3 -to vga_red_o[1]
set_location_assignment PIN_C2 -to vga_green_o[3]
set_location_assignment PIN_B2 -to vga_green_o[1]
set_location_assignment PIN_F1 -to vga_red_o[2]
set_location_assignment PIN_E4 -to vga_red_o[0]
set_location_assignment PIN_C1 -to vga_green_o[2]
set_location_assignment PIN_B1 -to vga_green_o[0]

set_location_assignment PIN_G5 -to vga_blue_o[3]
set_location_assignment PIN_G4 -to vga_clk_o
set_location_assignment PIN_G3 -to vga_blue_o[0]
set_location_assignment PIN_H2 -to vga_hsync_o
set_location_assignment PIN_H1 -to vga_blue_o[2]
set_location_assignment PIN_J3 -to vga_blue_o[1]
set_location_assignment PIN_J2 -to vga_de_o
set_location_assignment PIN_J1 -to vga_vsync_o

# You have to replace <ENTITY_PORT_NAME_xxx> with the name of the PMOD I/O port
# and/or clock port of your top entity
# set_location_assignment PIN_AA12 -to <ENTITY_PORT_NAME_CONNECTED_TO_PMOD3_CLK1>
# set_location_assignment PIN_AB12 -to <ENTITY_PORT_NAME_CONNECTED_TO_PMOD3_CLK2>
set_location_assignment PIN_AA16 -to uart0_txd_o
set_location_assignment PIN_AB16 -to uart0_rxd_i
# set_location_assignment PIN_AA15 -to <ENTITY_PORT_NAME_CONNECTED_TO_PMOD3_IO3>
# set_location_assignment PIN_AB15 -to <ENTITY_PORT_NAME_CONNECTED_TO_PMOD3_IO4>
