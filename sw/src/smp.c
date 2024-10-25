/**
 * @file smp.c
 * @author Niklaus Leuenberger <@NikLeberg>
 * @brief Symmetric Multi Processing for the neorv32.
 * @version 0.2
 * @date 2024-09-14
 *
 * @copyright Copyright (c) 2024 Niklaus Leuenberger
 *            SPDX-License-Identifier: MIT
 *
 */


#include "smp.h"

#include <neorv32_cpu.h>
#include <neorv32_cpu_amo.h>
#include <neorv32_cpu_csr.h>


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
    // The following assumes we do not have a core local d-cache. And if we have
    // one that it has coherency.
    *lock = SMP_SPINLOCK_UNLOCKED;
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
            asm volatile("nop");
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
