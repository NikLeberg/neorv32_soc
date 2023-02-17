# You have to replace <ENTITY_PORT_NAME_xxx> with the name of the PMOD I/O port
# of your top entity
# set_location_assignment PIN_F2 -to columns[3]
# set_location_assignment PIN_E3 -to columns[2]
set_location_assignment PIN_C2 -to dbg[0]
set_location_assignment PIN_B2 -to dbg[1]
# set_location_assignment PIN_F1 -to rows[3]
# set_location_assignment PIN_E4 -to rows[2]
set_location_assignment PIN_C1 -to dbg[2]
set_location_assignment PIN_B1 -to dbg[3]

set_location_assignment PIN_G5 -to dbg[4]
set_location_assignment PIN_G4 -to dbg[5]
# set_location_assignment PIN_G3 -to <ENTITY_PORT_NAME_CONNECTED_TO_PMOD2_IO3>
# set_location_assignment PIN_H2 -to <ENTITY_PORT_NAME_CONNECTED_TO_PMOD2_IO4>
set_location_assignment PIN_H1 -to dbg[6]
# set_location_assignment PIN_J3 -to a
# set_location_assignment PIN_J2 -to btn
# set_location_assignment PIN_J1 -to swt

# You have to replace <ENTITY_PORT_NAME_xxx> with the name of the PMOD I/O port
# and/or clock port of your top entity
# set_location_assignment PIN_AA12 -to <ENTITY_PORT_NAME_CONNECTED_TO_PMOD3_CLK1>
# set_location_assignment PIN_AB12 -to <ENTITY_PORT_NAME_CONNECTED_TO_PMOD3_CLK2>
set_location_assignment PIN_AA16 -to uart0_txd_o
set_location_assignment PIN_AB16 -to uart0_rxd_i
# set_location_assignment PIN_AA15 -to <ENTITY_PORT_NAME_CONNECTED_TO_PMOD3_IO3>
# set_location_assignment PIN_AB15 -to <ENTITY_PORT_NAME_CONNECTED_TO_PMOD3_IO4>
