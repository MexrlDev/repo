# P2JB (Patience to Jailbreak) – PS5 (FW ≤ 13.00)

 .1 Overview
  P2JB is a kernel-level issue in PlayStation 5 firmware up to and including 12.70. At a high level, it comes down to a missed credential reference release in sys_kqueueex, which leaves cr_ref on a ucred object incremented when the syscall fails in a specific way. By repeating that failure path enough times, the attacker can drive the credential reference count into an unsafe state and turn it into a much stronger kernel primitive. From there, the exploit chain can be extended into arbitrary read/write and, eventually, kernel code execution.
  Sony appears to have fixed the issue in firmware 13.00. The same path is not present on PS4, because its kqueue implementation does not keep a ucred reference in the same way.
  This note explains how the bug behaves, why the reference count leak matters, and what the exploit needs in practice.

---

· .2 Vulnerability details
  · .2.1 sys_kqueueex
    sys_kqueueex is basically a kqueue variant that accepts an optional name argument. The vulnerable path looks roughly like this:
    ```c
    int sys_kqueueex(struct thread *td, struct kqueueex_args *uap) {
        struct kqueue *kq;
        struct file *fp;
        int fd, error;
        char *name = NULL;
        error = falloc(td, &fp, &fd, 0);
        if (error)
            return error;
        kq = kqueue_alloc(td);
        if (kq == NULL) {
            error = ENOMEM;
            goto cleanup;
        }
        kq->kq_cred = crhold(td->td_ucred);
        if (uap->name != NULL) {
            name = malloc(MAXPATHLEN, M_TEMP, M_WAITOK);
            error = copyinstr(uap->name, name, MAXPATHLEN, NULL);
            if (error) {
                free(name, M_TEMP);
                goto cleanup;
            }
        }
        return fd;
    cleanup:
        fdclose(td, fp, fd);
        fdrop(fp, td);
        return error;
    }
    ```
    The bug is not just “a missing crfree()” in the abstract. The problem is that the failure path does not properly balance the credential reference in the way the kernel expects. In the PS5 implementation, the error path can leave the ucred reference count incremented permanently when copyinstr() fails on a non-NULL name pointer. That is the leak primitive.
    The important part is that the syscall accepts a user-supplied pointer, and if that pointer is invalid or otherwise causes copyinstr() to fail, the kernel takes the error branch. Repeating that branch over and over leaks references.
  · .2.2 ucred and cr_ref
    A ucred is the kernel object that stores process credentials: UID, GID, groups, and related privilege state. It is reference-counted.
    ```c
    struct ucred {
        uint32_t cr_ref;
        uid_t    cr_uid;
        uid_t    cr_ruid;
        uid_t    cr_svuid;
        gid_t    cr_gid;
        // ...
    };
    ```
    crhold() increments cr_ref, and crfree() decrements it. When the count reaches zero, the object is released back to the kernel heap. If that accounting is wrong, the result is either a leak or a use-after-free. In this case, the issue starts as a leak, but the exploit uses that leak to reach a much worse state.

---

· .3 Exploitation strategy
  The exploit is basically about turning a reference-counting mistake into a controlled kernel heap situation. The rough flow is:
  1. Leak one cr_ref per failed syscall.
  2. Drive the count toward an unsafe value.
  3. Open file descriptors to create controlled live references.
  4. Trigger the final release of the original ucred.
  5. Reclaim the freed memory with attacker-controlled data.
  6. Use file close / drop behavior to manipulate the fake object.
  · .3.1 Leaking references
    The initial primitive is simple: call sys_kqueueex with a bad non-NULL pointer that forces copyinstr() to fail. A kernel-space address, or any unmapped address, works for that.
    ```c
    for (int i = 0; i < many; i++)
        __sys_kqueueex((const char *)0x800000000000ULL);
    ```
    Each failing call leaves one extra reference behind. Because cr_ref is a 32-bit unsigned counter, repeated leaks eventually push it toward wraparound. Once the value is driven low enough, the object can be made to look eligible for release even though the attacker still has a handle on the overall state.
  · .3.2 Why threads help
    Doing this in a single thread is slow. In practice, a multi-threaded leak loop makes the count rise much faster, since all threads are operating on the same process credentials. That reduces the wait from something impractical to something manageable.
  · .3.3 Creating live references
    Before the count gets too low, the exploit opens a number of files. That matters because file allocation also takes credential references:
    ```c
    fp->f_cred = crhold(td->td_ucred);
    ```
    Those file descriptors now hold references that will outlive the original object if the main ucred is later freed. That gives the attacker a set of controlled handles into the same credential memory.
  · .3.4 Forcing the final free
    setuid() is used to swap the process onto a new credential object. Internally, the kernel creates a new ucred, copies the old state, and drops the old reference. If the attacker has arranged the count correctly, that final drop frees the original ucred while file descriptors still point at the old memory.
    At that point, the exploit has dangling pointers into a freed kernel object.
  · .3.5 Reclaiming the freed memory
    Once the old ucred has been freed, the next step is a heap spray. The goal is to get attacker-controlled data to land in the same allocation slot that used to hold the ucred.
    If that works, the dangling fp->f_cred pointers now resolve to a fake ucred structure controlled by the attacker. The structure can be shaped so that later crfree() calls act on values the attacker chose.
  · .3.6 Using close / fdrop to drive corruption
    When one of the file descriptors is closed, the kernel eventually calls crfree(fp->f_cred) on the fake object. If the fake cr_ref field is set up carefully, closing one file can push the counter to zero and free the same heap region again. If multiple file descriptors still point into that same freed object, the kernel can be made to free it more than once.
    That is where the bug stops being just a reference-counting mistake and becomes a heap corruption primitive.
  · .3.7 From heap corruption to read/write
    At that point the normal next step is to overlap the freed slot with some other kernel object and corrupt a useful field. Common targets are objects that eventually give a read or write primitive, such as pipe buffers, socket structures, or credential-related objects.
    From there, the exploit path is usually standard kernel exploitation: turn corruption into arbitrary read/write, use that to patch security-sensitive state, and then move on to code execution.

---

· .4 Requirements and environment
  This only makes sense on PS5 firmware 12.70 or earlier. Firmware 13.00 fixed the bug. PS4 is not affected, because its kqueue path does not take a ucred reference in the same way.
  The exploit also assumes some kind of kernel address knowledge or read primitive. The example PoC uses kernel_get_proc_ucred(getpid()), which implies the attacker already knows how to resolve kernel pointers.
  You also need enough file descriptors to stage the reference manipulation, plus a way to spray kernel heap allocations of roughly the same size as ucred. The exact spray primitive is implementation-dependent, but the timing matters: the spray has to land after the free and before the memory gets reused by something else.
  Multi-threading is not strictly required, but in practice it makes the leak phase much more realistic.

---

· .5 PoC walkthrough
  The PoC does not complete the full exploitation chain. It mainly demonstrates the reference-count effect.
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
  It first resolves the current process’s ucred address, reads the reference count, and then repeatedly calls the buggy syscall with an obviously invalid pointer. The purpose is to demonstrate that the error path leaks a reference each time.

---

· .6 Impact and mitigation
  The impact is straightforward: if fully exploited, the bug can lead to kernel-mode code execution and full control of the console.
  The fix is also straightforward: make sure the cleanup path always balances the credential reference, including the error branch. In practice, that means releasing the stored ucred before leaving the failing sys_kqueueex path. Sony’s PS5 13.00 patch appears to do exactly that.

---

· .7 Conclusion
  P2JB is a good example of how a small credential accounting bug can become serious. On its own, the flaw looks like a reference leak. With enough control over timing, heap state, and file descriptors, it can be pushed into a much more dangerous condition and used as a starting point for full kernel exploitation.
  The PoC only shows the first stage, but the overall chain is a textbook example of turning a subtle kernel bookkeeping mistake into a jailbreak path.
