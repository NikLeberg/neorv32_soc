# You have to replace <ENTITY_PORT_NAME_xxx> with the name of the Output port
# of your top entity

# DIP Switch 1
set_location_assignment PIN_V11  -to in_red[0]
set_location_assignment PIN_V10  -to in_red[1]
set_location_assignment PIN_AB10 -to in_red[2]
set_location_assignment PIN_AA10 -to in_red[3]
set_location_assignment PIN_AB9  -to in_green[0]
set_location_assignment PIN_AA9  -to in_green[1]
set_location_assignment PIN_AB8  -to in_green[2]
set_location_assignment PIN_AA8  -to in_green[3]

# DIP Switch 2
set_location_assignment PIN_Y8   -to in_blue[0]
set_location_assignment PIN_AB7  -to in_blue[1]
set_location_assignment PIN_AA7  -to in_blue[2]
set_location_assignment PIN_Y7   -to in_blue[3]
# set_location_assignment PIN_Y6   -to <ENTITY_PORT_NAME_CONNECTED_TO_DIP-switch2_5>
# set_location_assignment PIN_AB5  -to <ENTITY_PORT_NAME_CONNECTED_TO_DIP-switch2_6>
# set_location_assignment PIN_AA5  -to <ENTITY_PORT_NAME_CONNECTED_TO_DIP-switch2_7>
# set_location_assignment PIN_AB4  -to <ENTITY_PORT_NAME_CONNECTED_TO_DIP-switch2_8>

set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to in_red[0]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to in_red[1]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to in_red[2]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to in_red[3]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to in_green[0]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to in_green[1]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to in_green[2]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to in_green[3]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to in_blue[0]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to in_blue[1]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to in_blue[2]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to in_blue[3]
# set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to <ENTITY_PORT_NAME_CONNECTED_TO_DIP-switch2_5>
# set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to <ENTITY_PORT_NAME_CONNECTED_TO_DIP-switch2_6>
# set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to <ENTITY_PORT_NAME_CONNECTED_TO_DIP-switch2_7>
# set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to <ENTITY_PORT_NAME_CONNECTED_TO_DIP-switch2_8>

