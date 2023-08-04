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

static uint32_t lock_val = 0; // 0 = unlocked, 1 = locked
void lock(void) {
    uint32_t val, status;
    do {
        val = neorv32_cpu_load_reservate_word((uint32_t)&lock_val);
        if (val == 1) { // stil locked, store same value back
            status = neorv32_cpu_store_conditional_word((uint32_t)&lock_val, val);
        } else { // unlocked, set lock
            status = neorv32_cpu_store_conditional_word((uint32_t)&lock_val, 1);
        }
    } while (val == 1 || status == 1);
}
void unlock(void) {
    // We could write directly to lock_val but then the dcache could interfere.
    // Here we choose to use lr/sc again as it always bypasses the dcache.
    (void)neorv32_cpu_load_reservate_word((uint32_t)&lock_val);
    (void)neorv32_cpu_store_conditional_word((uint32_t)&lock_val, 0);
}

/**
 * @brief Main function
 *
 * @return will never return
 */
int main() {

    // let each hart blink its own led
    uint32_t hart_id = neorv32_cpu_csr_read(CSR_MHARTID);
    uint32_t delay = (128 << hart_id);
    for (;;) {
        lock();
        neorv32_gpio_pin_toggle(hart_id);
        unlock();
        delay_ms(delay);
    }

    // this should never be reached
    return 0;
}
