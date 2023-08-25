/**
 * @file smp.h
 * @author NikLeberg (niklaus.leuenb@gmail.com)
 * @brief Symmetric Multi Processing for the neorv32.
 * @version 0.1
 * @date 2023-08-09
 *
 * @copyright Copyright (c) 2023 Niklaus Leuenberger
 *
 */


#include <stdint.h>


#define SMP_SPINLOCK_UNLOCKED (0) //<! spinlock is unlocked
#define SMP_SPINLOCK_LOCKED (1)   //<! spinlock is locked


/**
 * @brief Spinlock data type.
 *
 * @note Must be initialized with SMP_SPINLOCK_INIT!
 */
typedef struct smp_spinlock_s {
    uint32_t lock;            //<! 0 = unlocked, 1 = locked
    uint32_t owner;           //<! hart id of owning cpu
    uint32_t recursion_count; //<! how often the same hart took the lock
} smp_spinlock_t;


/**
 * @brief Default initialization of an unlocked spinlock.
 *
 */
#define SMP_SPINLOCK_INIT \
    { .lock = SMP_SPINLOCK_UNLOCKED, .owner = UINT32_MAX, .recursion_count = 0 }

/**
 * @brief Aquire the lock, spins until lock was aquired.
 *
 * Lock is allowed to be taken recursively by the same cpu.
 *
 * @param lock lock to aquire
 */
void smp_spinlock_lock(smp_spinlock_t *lock);

/**
 * @brief Release the currently held spinlock.
 *
 * Lock is allowed to be given recursively by the same cpu.
 *
 * @param lock lock to release
 */
void smp_spinlock_unlock(smp_spinlock_t *lock);
