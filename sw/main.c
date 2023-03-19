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

#include "hpm_profile.h"

#define BAUD_RATE 19200
#define N_SAMPLES 100000

#define GCD_WB_BASE_ADDRESS 0x82000000

uint32_t get_random_uint32(void);


uint32_t calc_gcd_sw(uint32_t a, uint32_t b);
uint32_t calc_gcd_hw(uint32_t a, uint32_t b);
uint32_t calc_gcd_cfu(uint32_t a, uint32_t b);


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
    neorv32_uart_setup(NEORV32_UART0, BAUD_RATE, 0);

    // check available hardware extensions and compare with compiler flags
    neorv32_rte_check_isa(0); // silent = 0 -> show message if isa mismatch

    // reset and enable TRNG
    neorv32_trng_enable();

    // intro
    neorv32_uart_printf(NEORV32_UART0, "\n<<< NEORV32 GCD Accelerator Demo >>>\n\n");

    int i;
    uint32_t a, b;
    uint32_t r_sw = 0;
    uint32_t r_hw = 0;
    uint32_t r_cfu = 0;

    neorv32_uart_puts(NEORV32_UART0, "\nSimple check of GCD implementations...");
    a = 294;
    b = 546;
    r_sw = calc_gcd_sw(a, b);
    neorv32_uart_printf(NEORV32_UART0, "\ncalc_gcd_sw(%d, %d) = %d", a, b, r_sw);
    r_hw = calc_gcd_hw(a, b);
    neorv32_uart_printf(NEORV32_UART0, "\ncalc_gcd_hw(%d, %d) = %d", a, b, r_hw);
    r_cfu = calc_gcd_cfu(a, b);
    neorv32_uart_printf(NEORV32_UART0, "\ncalc_gcd_cfu(%d, %d) = %d", a, b, r_cfu);

    const hpm_setup_t profile_rng = {0, 1, HPMCNT_EVENT_CY, "rng"};
    const hpm_setup_t profile_sw = {0, 2, HPMCNT_EVENT_CY, "sw"};
    const hpm_setup_t profile_hw = {0, 3, HPMCNT_EVENT_CY, "hw"};
    const hpm_setup_t profile_cfu = {0, 4, HPMCNT_EVENT_CY, "cfu"};

    while (1) {
        neorv32_uart_puts(NEORV32_UART0, "\n\nRunning GCD benchmark...");
        // Reset and start the performance counter
        hpm_reset(profile_rng);
        hpm_reset(profile_sw);
        hpm_reset(profile_hw);
        hpm_reset(profile_cfu);
        hpm_start_measuring(profile_rng);
        hpm_start_measuring(profile_sw);
        hpm_start_measuring(profile_hw);
        hpm_start_measuring(profile_cfu);
        for (i = 0; i < N_SAMPLES; ++i) {
            // Generate two random variables
            hpm_begin(profile_rng);
            a = get_random_uint32();
            b = get_random_uint32();
            hpm_end(profile_rng);

            // Calculate the result using the software implementation and measure the execution time
            hpm_begin(profile_sw);
            r_sw = calc_gcd_sw(a, b);
            hpm_end(profile_sw);

            // Calculate the result using the memory mapped implementation and measure the execution time
            hpm_begin(profile_hw);
            r_hw = calc_gcd_hw(a, b);
            hpm_end(profile_hw);

            // Calculate the result using the custom function unit call and measure the execution time
            hpm_begin(profile_cfu);
            r_cfu = calc_gcd_cfu(a, b);
            hpm_end(profile_cfu);

            // Check if any error occurred. Print an error line if necessary
            if ((r_sw != r_hw) || (r_sw != r_cfu)) {
                neorv32_uart_printf(NEORV32_UART0, "\nIteration %i, inconsistency for gcd(%d, %d): r_sw = %d, r_hw = %d, r_cfu = %d", i, a, b, r_sw, r_hw, r_cfu);
            }
        }
        hpm_stop_measuring(profile_rng);
        hpm_stop_measuring(profile_sw);
        hpm_stop_measuring(profile_hw);
        hpm_stop_measuring(profile_cfu);

        // Print the result of the performance counters
        hpm_print(profile_rng);
        hpm_print(profile_sw);
        hpm_print(profile_hw);
        hpm_print(profile_cfu);

        neorv32_uart_puts(NEORV32_UART0, "\nRestart in 5 s ...");
        neorv32_cpu_delay_ms(5 * 1000);
    }

    // this should never be reached
    return 0;
}

uint32_t get_random_uint32(void) {
    uint8_t data[4];
    for (int i = 0; i < 4; ++i) {
        while (neorv32_trng_get(&data[i]))
            ;
    }
    return data[0] | ((uint32_t)data[1] << 8) | ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
}


// Software implementation of the gcd method
uint32_t calc_gcd_sw(uint32_t a, uint32_t b) {
    int n = 0;
    for (;;) {
        if (a == b)
            break;
        if ((a & 1u) == 0) { /* a is even */
            a >>= 1;
            if ((b & 1u) == 0) { /* b is even */
                b >>= 1;
                ++n;
            }
        } else if ((b & 1u) == 0) { /* b is even */
            b >>= 1;
        } else if (a > b) {
            a -= b;
        } else {
            b -= a;
        }
    }
    a <<= n;
    return a;
}

// Hardware implementation of the gcd method over wishbone bus
uint32_t calc_gcd_hw(uint32_t a, uint32_t b) {
    neorv32_cpu_store_unsigned_word(GCD_WB_BASE_ADDRESS, a);
    neorv32_cpu_store_unsigned_word(GCD_WB_BASE_ADDRESS + 4, b);
    uint32_t result;
    while ((result = neorv32_cpu_load_unsigned_word(GCD_WB_BASE_ADDRESS + 8)) == UINT32_MAX)
        ;
    return result;
}

// Hardware implementation of the gcd method using custom function unit
uint32_t calc_gcd_cfu(uint32_t a, uint32_t b) {
    return neorv32_cfu_r3_instr(0, 0, a, b);
}
