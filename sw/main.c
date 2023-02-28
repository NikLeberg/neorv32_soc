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
#define N_SAMPLES 100000

#define GCD_WB_BASE_ADDRESS 0x82000000

uint32_t get_random_uint32(void);

void hpm3_reset(void);
void hpm3_start(void);
void hpm3_stop(void);
uint32_t hpm3_print(char *name, uint32_t n);
void hpm4_reset(void);
void hpm4_start(void);
void hpm4_stop(void);
uint32_t hpm4_print(char *name, uint32_t n);
void hpm5_reset(void);
void hpm5_start(void);
void hpm5_stop(void);
uint32_t hpm5_print(char *name, uint32_t n);
void hpm6_reset(void);
void hpm6_start(void);
void hpm6_stop(void);
uint32_t hpm6_print(char *name, uint32_t n);
void hpm7_reset(void);
void hpm7_start(void);
void hpm7_stop(void);
uint32_t hpm7_print(char *name, uint32_t n);

uint32_t calc_gcd_sw(uint32_t a, uint32_t b);
uint32_t calc_gcd_hw(uint32_t a, uint32_t b);
uint32_t calc_gcd_ci_fun(uint32_t a, uint32_t b);
#define calc_gcd_ci_inl(a, b) neorv32_cfu_r3_instr(0, 0, a, b)


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

    // reset and enable TRNG
    neorv32_trng_enable();

    // intro
    neorv32_uart0_printf("\n<<< NEORV32 GCD Accelerator Demo >>>\n\n");

    int i;
    uint32_t a, b;
    uint32_t r_sw = 0;
    uint32_t r_hw = 0;
    uint32_t r_ci_fun = 0;
    uint32_t r_ci_inl = 0;

    while (1) {
        neorv32_uart0_puts("\nSimple check of GCD implementations...");
        a = 294;
        b = 546;
        r_sw = calc_gcd_sw(a, b);
        neorv32_uart0_printf("\ncalc_gcd_sw(%d, %d) = %d", a, b, r_sw);
        r_hw = calc_gcd_hw(a, b);
        neorv32_uart0_printf("\ncalc_gcd_hw(%d, %d) = %d", a, b, r_hw);
        r_ci_fun = calc_gcd_ci_fun(a, b);
        neorv32_uart0_printf("\ncalc_gcd_ci_fun(%d, %d) = %d", a, b, r_ci_fun);
        r_ci_inl = calc_gcd_ci_inl(a, b);
        neorv32_uart0_printf("\ncalc_gcd_ci_inl(%d, %d) = %d", a, b, r_ci_inl);

        neorv32_uart0_puts("\n\nRunning GCD benchmark...");
        // Reset the performance counters
        hpm3_reset();
        hpm4_reset();
        hpm5_reset();
        hpm6_reset();
        hpm7_reset();
        for (i = 0; i < N_SAMPLES; ++i) {
            // Generate two random variables
            a = get_random_uint32();
            b = get_random_uint32();

            // Calculate the result using the software implementation and measure the execution time
            hpm4_start();
            r_sw = calc_gcd_sw(a, b);
            hpm4_stop();

            // Calculate the result using the memory mapped implementation and measure the execution time
            hpm5_start();
            r_hw = calc_gcd_hw(a, b);
            hpm5_stop();

            // Calculate the result using the CI function call and measure the execution time
            hpm6_start();
            r_ci_fun = calc_gcd_ci_fun(a, b);
            hpm6_stop();

            // Calculate the result using the CI inline call and measure the execution time
            hpm7_start();
            r_ci_inl = calc_gcd_ci_inl(a, b);
            hpm7_stop();

            // Check if any error occurred. Print an error line if necessary
            if ((r_sw != r_hw) || (r_sw != r_ci_fun) || (r_sw != r_ci_inl)) {
                neorv32_uart0_printf("\nIteration %i, inconsistency for gcd(%d, %d): r_sw = %d, r_hw = %d, r_ci_fun = %d, r_ci_inl = %d", i, a, b, r_sw, r_hw, r_ci_fun, r_ci_inl);
            }
        }

        // Print the result of the performance counters
        hpm4_print("calc_gcd_sw", N_SAMPLES);
        hpm5_print("calc_gcd_hw", N_SAMPLES);
        hpm6_print("calc_gcd_ci_fun", N_SAMPLES);
        hpm7_print("calc_gcd_ci_inl", N_SAMPLES);

        neorv32_uart0_puts("\nRestart in 5 s ...");
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

void hpm3_reset(void) {
    hpm3_stop();
    // clear HPM counters (low and high word);
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER3, 0);
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER3H, 0);
    // configure trigger event: active cycle
    neorv32_cpu_csr_write(CSR_MHPMEVENT3, 1 << HPMCNT_EVENT_CY);
}
void hpm3_start(void) {
    uint32_t inhibit = neorv32_cpu_csr_read(CSR_MCOUNTINHIBIT);
    inhibit &= ~(1 << 3);
    neorv32_cpu_csr_write(CSR_MCOUNTINHIBIT, inhibit);
}
void hpm3_stop(void) {
    uint32_t inhibit = neorv32_cpu_csr_read(CSR_MCOUNTINHIBIT);
    inhibit |= (1 << 3);
    neorv32_cpu_csr_write(CSR_MCOUNTINHIBIT, inhibit);
}
uint32_t hpm3_print(char *name, uint32_t n) {
    uint32_t cycles = neorv32_cpu_csr_read(CSR_MHPMCOUNTER3);
    neorv32_uart0_printf("\nHPM[3]: %s -> %d average cycles", name, cycles / n);
    return cycles;
}

void hpm4_reset(void) {
    hpm4_stop();
    // clear HPM counters (low and high word);
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER4, 0);
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER4H, 0);
    // configure trigger event: active cycle
    neorv32_cpu_csr_write(CSR_MHPMEVENT4, 1 << HPMCNT_EVENT_CY);
}
void hpm4_start(void) {
    uint32_t inhibit = neorv32_cpu_csr_read(CSR_MCOUNTINHIBIT);
    inhibit &= ~(1 << 4);
    neorv32_cpu_csr_write(CSR_MCOUNTINHIBIT, inhibit);
}
void hpm4_stop(void) {
    uint32_t inhibit = neorv32_cpu_csr_read(CSR_MCOUNTINHIBIT);
    inhibit |= (1 << 4);
    neorv32_cpu_csr_write(CSR_MCOUNTINHIBIT, inhibit);
}
uint32_t hpm4_print(char *name, uint32_t n) {
    uint32_t cycles = neorv32_cpu_csr_read(CSR_MHPMCOUNTER4);
    neorv32_uart0_printf("\nHPM[4]: %s -> %d average cycles", name, cycles / n);
    return cycles;
}

void hpm5_reset(void) {
    hpm5_stop();
    // clear HPM counters (low and high word);
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER5, 0);
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER5H, 0);
    // configure trigger event: active cycle
    neorv32_cpu_csr_write(CSR_MHPMEVENT5, 1 << HPMCNT_EVENT_CY);
}
void hpm5_start(void) {
    uint32_t inhibit = neorv32_cpu_csr_read(CSR_MCOUNTINHIBIT);
    inhibit &= ~(1 << 5);
    neorv32_cpu_csr_write(CSR_MCOUNTINHIBIT, inhibit);
}
void hpm5_stop(void) {
    uint32_t inhibit = neorv32_cpu_csr_read(CSR_MCOUNTINHIBIT);
    inhibit |= (1 << 5);
    neorv32_cpu_csr_write(CSR_MCOUNTINHIBIT, inhibit);
}
uint32_t hpm5_print(char *name, uint32_t n) {
    uint32_t cycles = neorv32_cpu_csr_read(CSR_MHPMCOUNTER5);
    neorv32_uart0_printf("\nHPM[5]: %s -> %d average cycles", name, cycles / n);
    return cycles;
}

void hpm6_reset(void) {
    hpm6_stop();
    // clear HPM counters (low and high word);
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER6, 0);
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER6H, 0);
    // configure trigger event: active cycle
    neorv32_cpu_csr_write(CSR_MHPMEVENT6, 1 << HPMCNT_EVENT_CY);
}
void hpm6_start(void) {
    uint32_t inhibit = neorv32_cpu_csr_read(CSR_MCOUNTINHIBIT);
    inhibit &= ~(1 << 6);
    neorv32_cpu_csr_write(CSR_MCOUNTINHIBIT, inhibit);
}
void hpm6_stop(void) {
    uint32_t inhibit = neorv32_cpu_csr_read(CSR_MCOUNTINHIBIT);
    inhibit |= (1 << 6);
    neorv32_cpu_csr_write(CSR_MCOUNTINHIBIT, inhibit);
}
uint32_t hpm6_print(char *name, uint32_t n) {
    uint32_t cycles = neorv32_cpu_csr_read(CSR_MHPMCOUNTER6);
    neorv32_uart0_printf("\nHPM[6]: %s -> %d average cycles", name, cycles / n);
    return cycles;
}

void hpm7_reset(void) {
    hpm7_stop();
    // clear HPM counters (low and high word);
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER7, 0);
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER7H, 0);
    // configure trigger event: active cycle
    neorv32_cpu_csr_write(CSR_MHPMEVENT7, 1 << HPMCNT_EVENT_CY);
}
void hpm7_start(void) {
    uint32_t inhibit = neorv32_cpu_csr_read(CSR_MCOUNTINHIBIT);
    inhibit &= ~(1 << 7);
    neorv32_cpu_csr_write(CSR_MCOUNTINHIBIT, inhibit);
}
void hpm7_stop(void) {
    uint32_t inhibit = neorv32_cpu_csr_read(CSR_MCOUNTINHIBIT);
    inhibit |= (1 << 7);
    neorv32_cpu_csr_write(CSR_MCOUNTINHIBIT, inhibit);
}
uint32_t hpm7_print(char *name, uint32_t n) {
    uint32_t cycles = neorv32_cpu_csr_read(CSR_MHPMCOUNTER7);
    neorv32_uart0_printf("\nHPM[7]: %s -> %d average cycles", name, cycles / n);
    return cycles;
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

// Hardware implementation of the gcd method using PIO
uint32_t calc_gcd_hw(uint32_t a, uint32_t b) {
    // neorv32_uart0_printf("\na: %d, b: %d", a, b);
    neorv32_cpu_store_unsigned_word(GCD_WB_BASE_ADDRESS, a);
    neorv32_cpu_store_unsigned_word(GCD_WB_BASE_ADDRESS + 4, b);
    uint32_t result;
    while ((result = neorv32_cpu_load_unsigned_word(GCD_WB_BASE_ADDRESS + 8)) == UINT32_MAX)
        ;
    return result;
}

// Hardware implementation of the gcd method using CI
uint32_t calc_gcd_ci_fun(uint32_t a, uint32_t b) {
    return neorv32_cfu_r3_instr(0, 0, a, b);
}
