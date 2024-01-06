/**
 * @file smp.h
 * @author NikLeberg (niklaus.leuenb@gmail.com)
 * @brief Symmetric Multi Processing for the neorv32.
 * @version 0.2
 * @date 2024-01-04
 *
 * @copyright Copyright (c) 2024 Niklaus Leuenberger
 *
 */


#include <stdint.h>


#define SMP_SPINLOCK_UNLOCKED (0) //<! spinlock is unlocked
#define SMP_SPINLOCK_LOCKED (1)   //<! spinlock is locked

#define SMP_MUTEX_FREE (UINT32_MAX) //<! mutex is owned by noone


/**
 * @brief Spinlock data type.
 *
 * @note Must be initialized with SMP_SPINLOCK_INIT!
 */
typedef uint32_t smp_spinlock_t; //<! 0 = unlocked, 1 = locked

/**
 * @brief Mutex data type.
 *
 * @note Must be initialized with SMP_MUTEX_INIT!
 */
typedef struct smp_mutex_s {
    uint32_t owner;           //<! hart id of owning cpu, or SMP_MUTEX_FREE
    uint32_t recursion_count; //<! how often the same hart took the lock
    smp_spinlock_t lock;      //<! spinlock to protect data access
} smp_mutex_t;


/**
 * @brief Get the HART id of this HART.
 *
 * @return this HARTSs id
 */
#define smp_get_hart_id() neorv32_cpu_csr_read(CSR_MHARTID)

/**
 * @brief Set the inter processor interrupt (IPI) of a HART.
 *
 */
#define smp_set_ipi_for_hart(hart_id) \
    neorv32_cpu_store_unsigned_word(0xf0000000 + (4 * hart_id), 1)

/**
 * @brief Reset the inter processor interrupt (IPI) of a HART.
 *
 */
#define smp_reset_ipi_for_hart(hart_id) \
    neorv32_cpu_store_unsigned_word(0xf0000000 + (4 * hart_id), 0)

/**
 * @brief Default initialization of an unlocked spinlock.
 *
 */
#define SMP_SPINLOCK_INIT \
    SMP_SPINLOCK_UNLOCKED

/**
 * @brief Aquire the lock, spins until lock was aquired.
 *
 * @param lock lock to aquire
 */
void smp_spinlock_lock(smp_spinlock_t *lock);

/**
 * @brief Release the currently held spinlock.
 *
 * @param lock lock to release
 */
void smp_spinlock_unlock(smp_spinlock_t *lock);

/**
 * @brief Default initialization of an unlocked mutex.
 *
 */
#define SMP_MUTEX_INIT \
    { .owner = UINT32_MAX, .recursion_count = 0, .lock = SMP_SPINLOCK_INIT }

/**
 * @brief Take the mutex once.
 *
 * Mutex is allowed to be taken recursively by the same HART.
 *
 * @param mutex mutex to take
 */
void smp_mutex_take(smp_mutex_t *mutex);

/**
 * @brief Give a currently held mutex back once.
 *
 * Mutex is allowed to be given recursively by the same HART.
 *
 * @param mutex mutex to release
 */
void smp_mutex_give(smp_mutex_t *mutex);
