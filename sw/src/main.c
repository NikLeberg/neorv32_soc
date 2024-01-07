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

#include <FreeRTOS.h>
#include <task.h>

#include <neorv32.h>
#include "smp.h"

void vAssertCalled(void);
void vApplicationIdleHook(void);

extern void freertos_risc_v_trap_handler(void); // FreeRTOS core
static void setup_port(void);
static void blinky(void *args);
static void delay_ms(uint32_t time_ms);

// void msi_handler(void) {
//     smp_reset_ipi_for_hart(smp_get_hart_id());
// }

static smp_mutex_t mutex = SMP_MUTEX_INIT;

/**
 * @brief Main function
 *
 * @return will never return
 */
int main() {
    // setup hardware and port software
    setup_port();
    // create a simple task
    xTaskCreate(blinky, "blinky", configMINIMAL_STACK_SIZE, NULL, configMAX_PRIORITIES - 2, NULL);
    // start the scheduler
    vTaskStartScheduler();
    // will not get here unless something went horribly wrong
    for (;;) {
        neorv32_gpio_pin_toggle(1);
        neorv32_gpio_pin_toggle(2);
        delay_ms(100);
    }
}

static void setup_port(void) {
    // install the freeRTOS kernel trap handler
    neorv32_cpu_csr_write(CSR_MTVEC, (uint32_t)&freertos_risc_v_trap_handler);
    // // the first HART is responsible to wake up all other cores
    // uint32_t hart_id = neorv32_cpu_csr_read(CSR_MHARTID);
    // if (hart_id == 0) {
    //     // enable other cores with msi interrupt aka ipi
    //     smp_set_ipi_for_hart(1);
    //     smp_set_ipi_for_hart(2);
    //     smp_set_ipi_for_hart(3);
    //     smp_set_ipi_for_hart(4);
    // }
}

void vAssertCalled(void) {
    /* Flash the lowest 2 LEDs to indicate that assert was hit - interrupts are
    off here to prevent any further tick interrupts or context switches, so the
    delay is implemented as a busy-wait loop instead of a peripheral timer. */
    taskDISABLE_INTERRUPTS();
    neorv32_gpio_port_set(0);
    while (1) {
        for (int i = 0; i < (configCPU_CLOCK_HZ / 100); i++) {
            asm volatile("nop");
        }
        neorv32_gpio_pin_toggle(0);
        neorv32_gpio_pin_toggle(1);
    }
}

void vApplicationIdleHook(void) {
    // put CPU into sleep mote, it wakes up on any interrupt request
    neorv32_cpu_sleep();
}

static void blinky(void *args) {
    (void)args;
    uint32_t hart_id = neorv32_cpu_csr_read(CSR_MHARTID);
    for (;;) {
        neorv32_gpio_pin_toggle(0);
#ifndef SIMULATION
        vTaskDelay(pdMS_TO_TICKS(200));
#else
#warning "Running blinky task with no delay!"
        vTaskDelay(0);
#endif
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
