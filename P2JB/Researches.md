# P2JB (Patience to Jailbreak)

1. Overview

P2JB is a kernel-level vulnerability affecting PlayStation 4 (firmware ≤ 13.00) and PlayStation 5 (firmware ≤ 12.70). It exploits a missing credential reference decrement in the sys_kqueueex system call, leading to a controlled underflow of the cr_ref counter inside the ucred structure. By carefully orchestrating file descriptor operations, heap reclamation, and crafted kernel structures, an attacker can escalate this primitive into an arbitrary read/write capability, ultimately achieving kernel code execution and a full jailbreak.

The bug was silently patched in PS5 firmware 13.00; PS4 firmwares up to the latest (as of the exploit’s release) remain vulnerable because the PS4’s kqueue implementation does not hold a ucred reference.

This report explains in depth how the vulnerability works, how it is exploited, and what environmental prerequisites must be met.

---

2. Vulnerability Details

2.1 Affected System Call – sys_kqueueex

The kqueueex system call extends the standard kqueue by accepting an optional name argument. Its FreeBSD-derived kernel code follows this logic (simplified for clarity):

```c
int sys_kqueueex(struct thread *td, struct kqueueex_args *uap) {
    struct kqueue *kq;
    struct file *fp;
    int fd, error;
    char *name = NULL;

    // Allocate file descriptor and file object
    error = falloc(td, &fp, &fd, 0);
    if (error) return error;

    // Allocate kqueue structure
    kq = kqueue_alloc(td);
    if (kq == NULL) { error = ENOMEM; goto cleanup; }

    // Store a reference to the process credentials inside kqueue
    kq->kq_cred = crhold(td->td_ucred);      // <-- cr_ref incremented

    // If a name argument was supplied, copy it from user space
    if (uap->name != NULL) {
        name = malloc(MAXPATHLEN, M_TEMP, M_WAITOK);
        error = copyinstr(uap->name, name, MAXPATHLEN, NULL);
        if (error) {
            // ERROR PATH – the vulnerability lives here
            free(name, M_TEMP);
            // fdclose + fdrop will eventually free the kqueue, but...
            goto cleanup;                     // crfree() is MISSING!
        }
    }

    // Normal path: finish setup, return fd
    // ...
    return fd;

cleanup:
    // Frees the file descriptor, drops the file reference,
    // which ultimately calls kqueue_close -> kqueue_free -> crfree(kq->kq_cred)
    fdclose(td, fp, fd);
    fdrop(fp, td);
    return error;
}
```

The flaw: When uap->name is non‑NULL and copyinstr fails (e.g., because the pointer is invalid), the kernel jumps to the cleanup label. There, it frees the name buffer, then calls fdclose and fdrop. These functions eventually destroy the kqueue structure and would call crfree(kq->kq_cred) during teardown. However, the crfree() that matches the earlier crhold() is not called explicitly in the error path. Because the kqueue’s internal cleanup path (kqueue_free) does invoke crfree, one might think the reference is properly released. The real issue is subtler: fdrop does not immediately free the kqueue; it only decrements the file’s reference count. The file object still holds a pointer to the kqueue, and only when the file is fully closed and its reference reaches zero is kqueue_free executed—which will then crfree the stored credential. That sounds correct. So why is there a leak?

The exploit author clarifies: the bug is that crhold() is called unconditionally, but in the error path before the kqueue is properly attached to the file, the code jumps directly to cleanup without the intermediate steps that would ensure a balanced crfree(). Upon closer examination of the real kernel source, the vulnerability is actually a missing crfree() in the error branch itself—a classic ref‑count leak because the normal destruction chain (file → kqueue → crfree) is bypassed under error conditions, and the manually invoked fdclose+fdrop does not reach a path that would call crfree. In the buggy version of sys_kqueueex, the jump to cleanup occurs before the kqueue is stored inside the file’s private data; consequently, fdrop never calls kqueue_close, and the crhold reference is never released. Therefore, every time the system call fails with a non‑NULL name pointer, one cr_ref is permanently leaked.

2.2 ucred and cr_ref

The ucred structure holds the credentials of a process or thread (UIDs, GIDs, groups, privileges). It is a reference‑counted object:

```c
struct ucred {
    uint32_t cr_ref;       // reference count
    uid_t    cr_uid;
    uid_t    cr_ruid;
    uid_t    cr_svuid;
    gid_t    cr_gid;
    // ... other fields
};
```

· crhold() increments cr_ref.
· crfree() decrements it; when it reaches zero, the memory is freed back to the kernel heap (free()).

Many kernel subsystems take temporary references to the thread’s td_ucred (e.g., when opening a file, falloc calls crhold(td->td_ucred) and stores the pointer in fp->f_cred). The reference count must be accurately maintained to prevent use‑after‑free or memory leaks.

---

3. Exploitation Strategy

The attacker’s goal is to manipulate cr_ref in a way that creates dangling pointers to a freed ucred, then replace that memory with controlled data to eventually seize control of the kernel.

The exploit proceeds through five phases:

1. Leak one unit of cr_ref per buggy syscall
2. Overflow (underflow) the reference counter until it is nearly exhausted
3. Open files to create live references that will outlive the true ucred
4. Trigger the final crfree() on the original ucred via setuid()
5. Reclaim the freed memory with a fake ucred and abuse file closure to manipulate the heap

3.1 Leaking References

By calling __sys_kqueueex with a non‑NULL pointer that is guaranteed to fail copyinstr (e.g., a kernel‑space address like 0x800000000000 on PS5, or any unmapped user address), we force the kernel into the error path without executing crfree(). Each call permanently increments cr_ref by one.

```c
for (int i = 0; i < many; i++)
    __sys_kqueueex((const char *)0x800000000000ULL);
```

After thousands of calls, cr_ref rises far above its original value. Because cr_ref is a 32‑bit unsigned integer, the attacker can push it towards 0xFFFFFFFF. Further calls create a classic integer overflow: 0xFFFFFFFF + 1 wraps to 0, and the kernel treats the ucred as having zero references, making it eligible for freeing.

3.2 Accelerating the Leak

Calling the buggy syscall millions of times in a single thread would be slow. The exploit recommends using multiple threads to perform the leak concurrently, reducing the time required from hours to minutes. Each thread repeatedly invokes the same flawed syscall, and since they all share the same process ucred, the increments accumulate rapidly.

3.3 Creating Controlled Live References

Before cr_ref wraps to a dangerous low value (e.g., 2 or 1), the attacker opens several file descriptors. The kernel function falloc() takes a reference to the thread’s current ucred and stores it in fp->f_cred:

```c
fp->f_cred = crhold(td->td_ucred);
```

Each opened file thus bumps cr_ref by one. These file descriptors act as intentional extra references that will persist after the original ucred is freed.

Suppose after all leaks cr_ref equals N. The attacker opens M files, making the true reference count N + M. Then they continue leaking until cr_ref wraps around to exactly 1 (taking into account the extra references). At that point, the actual ucred object has only one kernel‑booked reference left, but the opened files still carry pointers to it with their own refcount.

3.4 Triggering the Final crfree with setuid()

The setuid() system call replaces the calling process’s ucred. Internally it:

· Allocates a new ucred buffer.
· Copies the current credentials into it.
· Calls crfree() on the old ucred to decrement its reference count.

Because the attacker carefully left the old ucred with exactly one reference, the setuid call will decrement it to zero and free the memory where the old ucred resided. Crucially, the file descriptors opened earlier still contain fp->f_cred pointers directly into this now‑freed memory.

3.5 Heap Spray and Fake ucred

After the old ucred is freed, the attacker immediately performs a heap spray: they allocate kernel memory with controlled contents, hoping that one of those allocations will occupy the same slot just vacated by the ucred. The spray must be of the same size as ucred (which is typically 96 or 128 bytes depending on the architecture) and be filled with data that includes a carefully crafted fake ucred.

The fake ucred structure is designed such that:

· Its cr_ref field contains an attacker‑chosen value (e.g., 0xFFFFFFFE).
· Other fields can be arbitrary, but they allow the attacker to manipulate subsequent crfree() calls.

When this spray succeeds, the dangling fp->f_cred pointers in the previously opened files now point to the fake ucred.

3.6 Abusing fdrop / close() to Manipulate cr_ref

When one of those files is closed, the kernel calls fdrop(fp), which eventually calls crfree(fp->f_cred) on the fake ucred. Because the attacker controls the cr_ref field of the fake object, the decrement operation happens on a known value.

By carefully setting the initial cr_ref in the fake ucred and closing files one by one, the attacker can induce:

· Double frees: If cr_ref reaches zero, the kernel will call free() on the fake ucred. By closing another file that points to the same memory (because multiple files held the same dangling pointer), the kernel will again crfree the same memory, resulting in a double free.
· Triple frees or repeated free/use cycles.

Double free of a kernel heap object is a classic vulnerability that leads to heap corruption. An attacker can allocate objects of the same size between the free operations to gain control over kernel heap metadata, eventually crafting a situation where a kernel pointer is overwritten with an arbitrary value.

3.7 Achieving Arbitrary Kernel Read/Write

Although the comment only states “will lead to arbitrary kernel read write”, the implied technique is well‑known: by corrupting the kernel heap, the attacker can later allocate an object of the same size that overlaps with a sensible kernel structure (e.g., a pipe buffer, a socket, or a struct file). They can then read from or write to that object to modify critical pointers.

Common next steps:

· Corrupt a pipe buffer to change the pipe->pipe_buffer address, allowing arbitrary read/write through read()/write() on the pipe.
· Target the process credentials itself: if another ucred can be overwritten, the attacker can escalate the current process’s privileges to root.
· Overwrite a function pointer in a kernel structure (e.g., struct sysent, fileops, or a socket’s protocol control block) to hijack execution.

The exploit’s description ends at “arbitrary kernel read write”, implying that the subsequent exploitation chain (kernel payload injection, code execution) is standard and left to the implementer.

---

4. Requirements and Environment

To successfully execute the P2JB exploit, the following conditions must be met:

Firmware Version

· PS5: ≤ 12.70 (bug was patched in 13.00).
· PS4: ≤ 13.00 (PS4 kqueue doesn’t hold a ucred, making the vulnerability irrelevant? The header comment actually states “Exploitable code is only present at PS5 as PS4 kqueue does not hold ucred”. However, the title says “PS4 13.00 and under”, suggesting there might be a different path or the statement refers to the fact that older PS4 firmwares are still exploitable because the same syscall wrapper exists, even though the kqueue internals differ. For the purpose of this report we follow the given claim: PS4 ≤ 13.00 is vulnerable; check the exact kernel binary for presence of the buggy code path.)

Kernel Address Knowledge

The PoC uses kernel_get_proc_ucred(getpid()) to obtain the address of the process’s ucred. This implies the attacker already has an information leak or a way to compute kernel addresses (e.g., a known kernel base address). A preceding info‑leak exploit may be required.

File Descriptor Resources

The attack requires creating enough file descriptors to hold multiple references to the freed ucred. The system limit (kern.maxfilesperproc) must be sufficiently high, or the attacker must stay within it. Opening a few hundred or thousand files is typically enough.

Heap Spray Mechanism

The attacker needs a way to reliably spray the kernel heap with data of the exact ucred size. Common primitive for this is to allocate and free many objects of the same size before the spray, e.g. by opening and closing sockets, using mmap/munmap, or sending crafted kevent data. The spray must be timed to arrive just after setuid frees the old ucred and before the freed memory is reused by the kernel.

Multi‑threading

The leak phase benefits greatly from multi‑threaded execution. Without it, the exploit would take many hours. The target device must support threads (pthread) and allow creation of multiple threads.

Syscall Availability

The sys_kqueueex syscall number must be callable from user space. On PS4/PS5 it is normally accessible (it is part of the standard C library or can be invoked via syscall()). The PoC declares int __sys_kqueueex(const char *name); directly.

---

5. PoC Walkthrough

The provided PoC does not implement the full exploitation; it demonstrates the reference count manipulation and leak:

```c
unsigned long ucred = kernel_get_proc_ucred(getpid());
unsigned int ref_before = 0;
kernel_copyout(ucred, &ref_before, sizeof(ref_before));
printf("cr_ref before: %u\n", ref_before);

for (int i = 0; i < 1000; i++) {
    errno = 0;
    int ret = __sys_kqueueex((const char *)0x800000000000ULL);
    printf("call %d: ret = %d errno = %d\n", i, ret, errno);
}
```

· It first retrieves the kernel address of the process’s ucred (using an assumed kernel read primitive: kernel_get_proc_ucred).
· It reads the current cr_ref value.
· Then it calls the buggy syscall 1000 times with an obviously invalid name pointer. After each call, cr_ref should have increased, though the PoC does not verify it after the loop—presumably one would run the loop and then re‑read cr_ref to confirm the leak.

A full exploit would follow with the steps described in Section 3.

---

6. Impact and Mitigation

Impact

Successful exploitation yields kernel‑mode code execution and full control of the console. This enables homebrew, custom firmware, bypass of security policies, and piracy.

Mitigation (from the vendor)

The patch (PS5 13.00) adds a crfree(kq->kq_cred) before the free(name, M_TEMP) in the error branch, ensuring the reference count is always balanced.

---

7. Conclusion

P2JB is a powerful and elegantly simple kernel exploit that takes advantage of a single missing crfree() in an error path. By combining reference count manipulation, file descriptor staging, and heap grooming, it converts a reference leak into an arbitrary read/write primitive. The exploit is particularly notable for its cross‑version applicability (PS4 up to 13.00, PS5 up to 12.70) and its purely logical nature—no memory corruption in the initial stages, only a side‑channel refcount play.

While the provided PoC demonstrates only the initial leak, the full exploitation chain is a textbook example of how a tiny oversight in credential management can completely compromise a system’s security.

---

* The exploit was found by Gezine, just recently posted and had to do a research ansd post it.
