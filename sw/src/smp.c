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


void smp_spinlock_lock(smp_spinlock_t *lock) {
    // If amoswap returns SMP_SPINLOCK_LOCKED, the lock was already set, and
    // we must continue to loop. If it returns SMP_SPINLOCK_UNLOCKED, then
    // the lock was free, and we have now acquired it.
    while (neorv32_cpu_amoswapw((uint32_t)lock, SMP_SPINLOCK_LOCKED) == SMP_SPINLOCK_LOCKED) {
        // We potentially have no dcache and if we have then certainly no
        // coherency hetween the caches. Relax the bus utilization with nop.
        asm volatile("nop");
    }
}

void smp_spinlock_unlock(smp_spinlock_t *lock) {
    // Assuming no dcache the following would work:
    //     *lock = SMP_SPINLOCK_UNLOCKED;
    // But we potentially have a dcache and no coherency (so far).
    // We reuse the store-conditional instruction as it is always uncached.
    neorv32_cpu_store_conditional_word((uint32_t)lock, SMP_SPINLOCK_UNLOCKED);
}

void smp_mutex_take(smp_mutex_t *mutex) {
    // Check if we currently own this mutex, if we do, we can simply increment
    // the recursion counter. But if owned by another HART, then we have to give
    // back the spinlock, wait a bit, lock it again and again check the owner in
    // the hope that the previous owner gave it back.
    smp_spinlock_lock(&mutex->lock);
    uint32_t hart_id = smp_get_hart_id();
    if (mutex->owner == hart_id) {
        mutex->recursion_count++;
    } else {
        while (mutex->owner != SMP_MUTEX_FREE) {
            smp_spinlock_unlock(&mutex->lock);
            smp_spinlock_lock(&mutex->lock);
        }
        mutex->owner = hart_id;
        mutex->recursion_count = 0;
    }
    smp_spinlock_unlock(&mutex->lock);
}

void smp_mutex_give(smp_mutex_t *mutex) {
    smp_spinlock_lock(&mutex->lock);
    if (mutex->owner == smp_get_hart_id()) {
        if (mutex->recursion_count > 0) {
            mutex->recursion_count--;
        }
        if (mutex->recursion_count == 0) {
            mutex->owner = SMP_MUTEX_FREE;
        }
    }
    smp_spinlock_unlock(&mutex->lock);
}
