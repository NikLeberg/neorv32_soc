/**
 * @file smp.c
 * @author NikLeberg (niklaus.leuenb@gmail.com)
 * @brief Symmetric Multi Processing for the neorv32.
 * @version 0.1
 * @date 2023-08-09
 *
 * @copyright Copyright (c) 2023 Niklaus Leuenberger
 *
 */


#include "smp.h"

#include <neorv32_cpu.h>
#include <neorv32_cpu_csr.h>
#include <neorv32_cpu_amo.h>


#define get_hart_id() neorv32_cpu_csr_read(CSR_MHARTID)

void smp_spinlock_lock(smp_spinlock_t *lock) {
    // uint32_t hart_id = get_hart_id();
    // if (lock->owner == hart_id) {
    //     // We are the current owner of the spinlock. Simply increment counter.
    //     ++(lock->recursion_count);
    // } else {
    // If amoswap returns SMP_SPINLOCK_LOCKED, the lock was already set, and
    // we must continue to loop. If it returns SMP_SPINLOCK_UNLOCKED, then
    // the lock was free, and we have now acquired it.
    while (neorv32_cpu_amoswapw((uint32_t)&lock->lock, SMP_SPINLOCK_LOCKED) == SMP_SPINLOCK_LOCKED) {
        // We potentially have no dcache and if we have then certainly no
        // coherency hetween the caches. Relax the bus utilization with nop.
        asm volatile("nop");
    }
    //     // Assign lock to us.
    //     lock->owner = hart_id;
    // }
}

void smp_spinlock_unlock(smp_spinlock_t *lock) {
    // Assuming no dcache the following would work:
    //     lock->lock = SMP_SPINLOCK_UNLOCKED;
    // But we potentially have a dcache and no coherency (so far).
    // We reuse the store-conditional instruction as it is always uncached.
    neorv32_cpu_store_conditional_word((uint32_t)&lock->lock, SMP_SPINLOCK_UNLOCKED);
}
