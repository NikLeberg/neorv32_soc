#ifndef hpm_profile
#define hpm_profile

#ifdef __cplusplus
extern "C" {
#endif

#include <neorv32.h>


typedef struct {
    const uint32_t primary;
    const uint32_t secondary;
    enum NEORV32_HPMCNT_EVENT_enum event;
    const char *name;
} hpm_setup_t;

inline void __attribute__((always_inline)) hpm_reset(const hpm_setup_t hpm) {
    // clear primary HPM counters (low and high word)
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER3 + hpm.primary, 0);
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER3H + hpm.primary, 0);
    // clear secondary HPM counters (low and high word)
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER3 + hpm.secondary, 0);
    neorv32_cpu_csr_write(CSR_MHPMCOUNTER3H + hpm.secondary, 0);
}

inline void __attribute__((always_inline)) hpm_start_measuring(const hpm_setup_t hpm) {
    // configure trigger event of both counters
    neorv32_cpu_csr_write(CSR_MHPMEVENT3 + hpm.primary, 1 << hpm.event);
    neorv32_cpu_csr_write(CSR_MHPMEVENT3 + hpm.secondary, 1 << hpm.event);
    // start primary counter
    neorv32_cpu_csr_clr(CSR_MCOUNTINHIBIT, 1 << (hpm.primary + 3));
}

inline void __attribute__((always_inline)) hpm_stop_measuring(const hpm_setup_t hpm) {
    // stop primary counter
    neorv32_cpu_csr_set(CSR_MCOUNTINHIBIT, 1 << (hpm.primary + 3));
}

inline void __attribute__((always_inline)) hpm_begin(const hpm_setup_t hpm) {
    // start secondary counter
    neorv32_cpu_csr_clr(CSR_MCOUNTINHIBIT, 1 << (hpm.secondary + 3));
}

inline void __attribute__((always_inline)) hpm_end(const hpm_setup_t hpm) {
    // stop secondary counter
    neorv32_cpu_csr_set(CSR_MCOUNTINHIBIT, 1 << (hpm.secondary + 3));
}

inline void __attribute__((always_inline)) hpm_print(const hpm_setup_t hpm) {
    uint32_t count_primary = neorv32_cpu_csr_read(CSR_MHPMCOUNTER3 + hpm.primary);
    uint32_t count_secondary = neorv32_cpu_csr_read(CSR_MHPMCOUNTER3 + hpm.secondary);
    uint64_t ratio = (uint64_t)100 * (uint64_t)count_secondary / count_primary;
    neorv32_uart_printf(NEORV32_UART0, "\nHPM[%s]: %d / %d => %d % ", hpm.name, count_secondary, count_primary, (uint32_t)ratio);
}

// inline void __attribute__((always_inline)) hpm_start(const int hpm_id) {
//     neorv32_cpu_csr_clr(CSR_MCOUNTINHIBIT, 1 << (hpm_id + 3));
// }
// inline void __attribute__((always_inline)) hpm_stop(const int hpm_id) {
//     neorv32_cpu_csr_set(CSR_MCOUNTINHIBIT, 1 << (hpm_id + 3));
// }
// inline void __attribute__((always_inline)) hpm_reset(const int hpm_id) {
//     hpm_stop(hpm_id);
//     // clear HPM counters (low and high word);
//     neorv32_cpu_csr_write(CSR_MHPMCOUNTER3 + hpm_id, 0);
//     neorv32_cpu_csr_write(CSR_MHPMCOUNTER3H + hpm_id, 0);
//     // configure trigger event: active cycle
//     neorv32_cpu_csr_write(CSR_MHPMEVENT3 + hpm_id, 1 << HPMCNT_EVENT_IR);
//     // neorv32_cpu_csr_write(CSR_MHPMEVENT3 + hpm_id, 1 << HPMCNT_EVENT_CY);
// }
// inline uint32_t __attribute__((always_inline)) hpm_print(const int hpm_id, char *name, uint32_t n) {
//     uint32_t cycles = neorv32_cpu_csr_read(CSR_MHPMCOUNTER3 + hpm_id);
//     if (n > 0) {
//         neorv32_uart0_printf("\nHPM[%d]: %s -> %d on average", hpm_id, name, cycles / n);
//     } else {
//         neorv32_uart0_printf("\nHPM[%d]: %s -> %d", hpm_id, name, cycles);
//     }
//     return cycles;
// }

#ifdef __cplusplus
}
#endif

#endif // hpm_profile