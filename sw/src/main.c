/**
 * @file main.c
 * @author Leuenberger Niklaus <leuen4@bfh.ch>
 * @brief Main application for NEORV32 processor.
 * @version 0.2
 * @date 2023-03-23
 *
 * @copyright Copyright (c) 2023 Niklaus Leuenberger
 *
 */


#include <neorv32.h>
#include "smp.h"

void delay_ms(uint32_t time_ms) {

#ifndef SIMULATION
    uint32_t clock = 50000000; // clock ticks per second
    clock = clock / 1000;      // clock ticks per ms
    uint64_t wait_cycles = ((uint64_t)clock) * ((uint64_t)time_ms);
    const uint32_t loop_cycles_c = 16; // clock cycles per iteration of the ASM loop
    uint32_t iterations = (uint32_t)(wait_cycles / loop_cycles_c);
#else
#warning "Simulating delay_ms as cycles instead of miliseconds!"
    // When simulating, don't do the full wait, only wait a few clocks.
    uint32_t iterations = time_ms;
#endif

    asm volatile(" .balign 4                    \n" // make sure this is 32-bit aligned
                 " 1:                           \n"
                 " beq  %[cnt_r], zero, 2f      \n" // 3 cycles (not taken)
                 " beq  %[cnt_r], zero, 2f      \n" // 3 cycles (never taken)
                 " addi %[cnt_w], %[cnt_r], -1  \n" // 2 cycles
                 " nop                          \n" // 2 cycles
                 " j    1b                      \n" // 6 cycles
                 " 2: "
                 : [cnt_w] "=r"(iterations)
                 : [cnt_r] "r"(iterations));
}

void msi_handler(void) {
    smp_reset_ipi_for_hart(smp_get_hart_id());
}

static smp_mutex_t mutex = SMP_MUTEX_INIT;

/**
 * @brief Main function
 *
 * @return will never return
 */
int main() {

    // let each hart blink its own led
    uint32_t hart_id = neorv32_cpu_csr_read(CSR_MHARTID);
    uint32_t delay = (128 << hart_id);

    if (hart_id == 0) {
        delay_ms(32);
        // enable other cores with msi interrupt aka ipi
        smp_set_ipi_for_hart(1);
        smp_set_ipi_for_hart(2);
        smp_set_ipi_for_hart(3);
        smp_set_ipi_for_hart(4);
    }

    for (;;) {
        smp_mutex_take(&mutex);
        neorv32_gpio_pin_toggle(hart_id);
        smp_mutex_give(&mutex);
        delay_ms(delay);
    }

    // this should never be reached
    return 0;
}
