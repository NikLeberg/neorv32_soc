/**
 * @file main.c
 * @author Leuenberger Niklaus <leuen4@bfh.ch>
 * @brief Main application for NEORV32 processor.
 * @version 0.1
 * @date 2023-02-06
 *
 * @copyright Copyright (c) 2023 Niklaus Leuenberger
 *
 */


#include <neorv32.h>

#define BAUD_RATE 19200

void activity_led(void);

/**
 * @brief Main function
 *
 * @return will never return
 */
int main() {

    // capture all exceptions and give debug info via UART
    neorv32_rte_setup();

    // disable all interrupt sources
    neorv32_cpu_csr_write(CSR_MIE, 0);

    // clear GPIO output (set all bits to 0)
    neorv32_gpio_port_set(0);

    // init UART at default baud rate, no parity bits, ho hw flow control
    neorv32_uart0_setup(BAUD_RATE, PARITY_NONE, FLOW_CONTROL_NONE);

    // check available hardware extensions and compare with compiler flags
    neorv32_rte_check_isa(0); // silent = 0 -> show message if isa mismatch

    // intro
    neorv32_uart0_printf("\n<<< NEORV32 Application >>>\n\n");


    while (1) {
        activity_led();
        neorv32_cpu_delay_ms(100);
    }

    // this should never be reached
    return 0;
}

void activity_led(void) {
    static uint32_t cnt;
    neorv32_gpio_port_set(cnt++ & 0xFF); // increment counter and mask for lowest 8 bit
}
