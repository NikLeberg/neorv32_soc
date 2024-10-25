/**
 * @file main.c
 * @author Niklaus Leuenberger <@NikLeberg>
 * @brief Main application for NEORV32 processor.
 * @version 0.3
 * @date 2024-10-25
 *
 * @copyright Copyright (c) 2024 Niklaus Leuenberger
 *            SPDX-License-Identifier: MIT
 *
 */

#include "smp.h"
#include <neorv32.h>

static void blinky(void *args);
static void delay_ms(uint32_t time_ms);

static smp_mutex_t mutex = SMP_MUTEX_INIT;

/**
 * @brief Main function
 *
 * @return will never return
 */
int main() {
    // wake other harts with msi interrupt aka ipi
    for (int i = 1; i < NUM_HARTS; ++i) {
        smp_set_ipi_for_hart(i);
    }

    blinky(NULL);
}

/**
 * @brief Main function of secondary HARTS
 *
 * @return will never return
 */
int secondary_main() {
    blinky(NULL);
}

static void blinky(void *args) {
    (void)args;
    uint32_t hart_id = neorv32_cpu_csr_read(CSR_MHARTID);
    for (;;) {
        smp_mutex_take(&mutex);
        neorv32_gpio_pin_toggle(hart_id);
        smp_mutex_give(&mutex);
        delay_ms(100);
    }
}

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
