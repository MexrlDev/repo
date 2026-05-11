| Hex | Dec | Name(s) | Description |
|:--|:--|:--|:--|
| `0x01` | 1 | `exit` | Terminate the calling process |
| `0x02` | 2 | `fork` | Create a child process |
| `0x03` | 3 | `read`, `read_sys` | Read from a file descriptor |
| `0x04` | 4 | `write`, `write_sys` | Write to a file descriptor |
| `0x05` | 5 | `open`, `open_sys` | Open a file |
| `0x06` | 6 | `close`, `close_sys` | Close a file descriptor |
| `0x07` | 7 | `wait4` | Wait for process termination |
| `0x0A` | 10 | `unlink` | Delete a file |
| `0x0C` | 12 | `chdir` | Change working directory |
| `0x0F` | 15 | `chmod` | Change file permissions |
| `0x14` | 20 | `getpid` | Get process ID |
| `0x17` | 23 | `setuid` | Set user ID |
| `0x18` | 24 | `getuid` | Get user ID |
| `0x19` | 25 | `geteuid` | Get effective user ID |
| `0x1B` | 27 | `recvmsg` | Receive socket message |
| `0x1C` | 28 | `sendmsg` | Send socket message |
| `0x1D` | 29 | `recvfrom` | Receive datagram |
| `0x1E` | 30 | `accept`, `accept_sys` | Accept socket connection |
| `0x1F` | 31 | `getpeername` | Get socket peer name |
| `0x20` | 32 | `getsockname` | Get socket name |
| `0x21` | 33 | `access` | Check file access permissions |
| `0x22` | 34 | `chflags` | Change file flags |
| `0x23` | 35 | `fchflags` | Change file flags on open file |
| `0x24` | 36 | `sync` | Schedule filesystem sync |
| `0x25` | 37 | `kill` | Send signal to process |
| `0x27` | 39 | `getppid` | Get parent process ID |
| `0x29` | 41 | `dup` | Duplicate file descriptor |
| `0x2A` | 42 | `pipe` | Create a pipe |
| `0x2B` | 43 | `getegid` | Get effective group ID |
| `0x2C` | 44 | `profil` | Execution time profile |
| `0x2F` | 47 | `getgid` | Get real group ID |
| `0x31` | 49 | `reboot` | Reboot system |
| `0x32` | 50 | `mmap (old)` | Old memory mapping syscall |
| `0x35` | 53 | `sigpending` | Examine pending signals |
| `0x36` | 54 | `ioctl` | Device control operation |
| `0x37` | 55 | `sigreturn` | Return from signal handler |
| `0x38` | 56 | `sigprocmask` | Examine/change blocked signals |
| `0x3B` | 59 | `execve` | Execute a program |
| `0x41` | 65 | `truncate` | Truncate file |
| `0x49` | 73 | `munmap` | Unmap memory region |
| `0x4A` | 74 | `mprotect` | Change memory protection |
| `0x4B` | 75 | `madvise` | Advise kernel about memory usage |
| `0x4E` | 78 | `getdirentries` | Read directory entries |
| `0x4F` | 79 | `statfs` | Filesystem statistics |
| `0x50` | 80 | `fstatfs` | Filesystem stats for open file |
| `0x53` | 83 | `getrlimit` | Get resource limits |
| `0x56` | 86 | `lseek (old)` | Old file offset reposition |
| `0x59` | 89 | `sysarch` | Architecture-specific syscall |
| `0x5A` | 90 | `dup2` | Duplicate FD to target number |
| `0x5C` | 92 | `fcntl` | File control |
| `0x5D` | 93 | `select` | I/O multiplexing |
| `0x5F` | 95 | `fsync` | Synchronise file state |
| `0x60` | 96 | `setpriority` | Set process priority |
| `0x61` | 97 | `socket` | Create socket |
| `0x62` | 98 | `connect` | Connect socket |
| `0x63` | 99 | `netcontrol` | PS4 network event queue management |
| `0x64` | 100 | `getpriority` | Get process priority |
| `0x65` | 101 | `send` | Send socket data |
| `0x66` | 102 | `recv` | Receive socket data |
| `0x68` | 104 | `bind`, `bind_sys` | Bind socket name |
| `0x69` | 105 | `setsockopt` | Set socket options |
| `0x6A` | 106 | `listen`, `listen_sys` | Listen for socket connections |
| `0x71` | 113 | `gettimeofday` | Get current time |
| `0x72` | 114 | `getrusage` | Get resource usage |
| `0x74` | 116 | `__sysctl` | Get/set system information |
| `0x75` | 117 | `umask` | Set file creation mask |
| `0x76` | 118 | `getsockopt` | Get socket options |
| `0x78` | 120 | `readv` | Scatter read |
| `0x79` | 121 | `writev` | Gather write |
| `0x7A` | 122 | `settimeofday` | Set system time |
| `0x7C` | 124 | `setlogin` | Set login name |
| `0x7D` | 125 | `getlogin` | Get login name |
| `0x7E` | 126 | `acct` | Process accounting |
| `0x7F` | 127 | `sigaltstack` | Alternate signal stack |
| `0x80` | 128 | `rename` | Rename file |
| `0x83` | 131 | `flock` | Advisory file lock |
| `0x85` | 133 | `munlockall` | Unlock all mapped memory |
| `0x86` | 134 | `shutdown` | Shutdown socket connection |
| `0x87` | 135 | `socketpair` | Create socket pair |
| `0x88` | 136 | `mkdir` | Create directory |
| `0x89` | 137 | `rmdir` | Remove directory |
| `0x8A` | 138 | `utimes` | Change file timestamps |
| `0x8C` | 140 | `adjtime` | Adjust system time |
| `0x8D` | 141 | `setsid` | Create session |
| `0x93` | 147 | `quotactl` | Disk quota management |
| `0xA5` | 165 | `nfssvc` | NFS daemon service |
| `0xB6` | 182 | `getgroups` | Get supplementary groups |
| `0xB7` | 183 | `setgroups` | Set supplementary groups |
| `0xBC` | 188 | `stat`, `stat_sys` | File status |
| `0xBD` | 189 | `lstat` | Symlink-aware file status |
| `0xBE` | 190 | `fstat` | File status for open file |
| `0xC3` | 195 | `setrlimit` | Set resource limits |
| `0xCB` | 203 | `mlock` | Lock mapped memory |
| `0xCC` | 204 | `munlock` | Unlock mapped memory |
| `0xCE` | 206 | `fchmod` | Change permissions on open file |
| `0xD1` | 209 | `fpathconf` | Path configuration query |
| `0xE8` | 232 | `sched_yield` | Yield processor |
| `0xEC` | 236 | `sched_setparam` | Set scheduling parameters |
| `0xED` | 237 | `sched_getparam` | Get scheduling parameters |
| `0xEE` | 238 | `sched_setscheduler` | Set scheduling policy |
| `0xEF` | 239 | `sched_getscheduler` | Get scheduling policy |
| `0xF0` | 240 | `nanosleep` | High-resolution sleep |
| `0x110` | 272 | `getdents` | Read directory entries |
| `0x121` | 289 | `wait6` | Modern process/thread wait |
| `0x122` | 290 | `thr_create (old)` | Create kernel thread |
| `0x136` | 310 | `statvfs` | Modern filesystem statistics |
| `0x13B` | 315 | `kldload` | Load kernel module |
| `0x144` | 324 | `kldstat` | Kernel module status |
| `0x145` | 325 | `kldunload` | Unload kernel module |
| `0x147` | 327 | `kldfind` | Find kernel module |
| `0x148` | 328 | `kldnext` | Get next module ID |
| `0x14A` | 330 | `kldfirstmod` | Get first module ID |
| `0x14C` | 332 | `kldsym` | Lookup kernel symbol |
| `0x14D` | 333 | `jail` | Create jail |
| `0x14E` | 334 | `jail_attach` | Attach to jail |
| `0x154` | 340 | `kqueue` | Create kernel event queue |
| `0x155` | 341 | `kevent` | Monitor kernel events |
| `0x157` | 343 | `__realpathat` | Resolve pathname |
| `0x159` | 345 | `pdfork` | Fork with process descriptor |
| `0x15A` | 346 | `pdkill` | Signal via process descriptor |
| `0x188` | 392 | `thr_kill` | Send signal to thread |
| `0x189` | 393 | `thr_exit` | Exit current thread |
| `0x18D` | 397 | `jail_remove` | Remove jail |
| `0x190` | 400 | `lpathconf` | Path configuration query |
| `0x192` | 402 | `cap_enter` | Enter capability mode |
| `0x193` | 403 | `cap_getmode` | Get capability mode |
| `0x1A0` | 416 | `procctl` | Process control |
| `0x1A5` | 421 | `thr_new` | Create new thread |
| `0x1A6` | 422 | `thr_wake` | Wake thread |
| `0x1A7` | 423 | `thr_suspend` | Suspend thread |
| `0x1AD` | 429 | `closefrom` | Close FD range |
| `0x1B9` | 441 | `posix_openpt` | Open pseudo-terminal |
| `0x1BA` | 442 | `posix_fallocate` | Allocate file space |
| `0x1BB` | 443 | `pselect` | Select with signal mask |
| `0x1BC` | 444 | `poll` | Poll I/O |
| `0x1C6` | 454 | `getcontext` | Get execution context |
| `0x1C7` | 455 | `thr_new (new)` | Modern thread creation |
| `0x1C8` | 456 | `thr_exit (new)` | Modern thread exit |
| `0x1D2` | 466 | `rtprio_thread` | Thread realtime priority |
| `0x1DD` | 477 | `mmap`, `mmap_sys` | Modern memory mapping |
| `0x1DE` | 478 | `lseek` | Reposition file offset |
| `0x1DF` | 479 | `truncate` | Modern truncate syscall |
| `0x1E0` | 480 | `ftruncate` | Truncate open file |
| `0x1E6` | 486 | `aio_read` | Async read |
| `0x1E7` | 487 | `cpuset_getaffinity` | Get CPU affinity |
| `0x1E8` | 488 | `cpuset_setaffinity` | Set CPU affinity |
| `0x1F3` | 499 | `getfsstat` | Mounted filesystem list |
| `0x20A` | 522 | `__getcwd` | Get current working directory |
| `0x214` | 532 | `posix_fadvise` | File access advice |
| `0x215` | 533 | `jitshm_create` | PS4 JIT shared memory create |
| `0x216` | 534 | `jitshm_destroy` | Destroy JIT shared memory |
| `0x217` | 535 | `jitshm_map` | Map JIT shared memory |
| `0x218` | 536 | `jitshm_unmap` | Unmap JIT shared memory |
| `0x21A` | 538 | `evf_create` | PS4 event flag create |
| `0x21B` | 539 | `evf_delete` | Delete event flag |
| `0x21C` | 540 | `evf_set` | Set event flag |
| `0x21D` | 541 | `evf_clear` | Clear event flag |
| `0x21E` | 542 | `evf_wait` | Wait for event flag |
| `0x21F` | 543 | `evf_poll` | Poll event flag |
| `0x249` | 585 | `is_in_sandbox` | Check sandbox status |
| `0x24A` | 586 | `sandbox_enter` | Enter sandbox |
| `0x24B` | 587 | `sandbox_leave` | Leave sandbox |
| `0x24C` | 588 | `sandbox_control` | Sandbox management |
| `0x262` | 610 | `thr_suspend_ucontext` | Suspend thread with context |
| `0x263` | 611 | `thr_resume_ucontext` | Resume suspended thread |
| `0x264` | 612 | `thr_set_name` | Set thread name |
| `0x265` | 613 | `thr_get_name` | Get thread name |
| `0x267` | 615 | `thr_self` | Get thread ID |
| `0x268` | 616 | `thr_join` | Wait for thread |
| `0x269` | 617 | `thr_detach` | Detach thread |
| `0x26A` | 618 | `thr_set_prio` | Set thread priority |
| `0x26B` | 619 | `thr_get_prio` | Get thread priority |
| `0x26C` | 620 | `thr_getschedparam` | Get scheduling params |
| `0x26E` | 622 | `thr_setschedparam` | Set scheduling params |
| `0x26F` | 623 | `thr_yield` | Yield processor |
| `0x270` | 624 | `thr_setaffinity` | Set CPU affinity |
| `0x271` | 625 | `thr_getaffinity` | Get CPU affinity |
| `0x272` | 626 | `thr_curcpu` | Get current CPU |
| `0x273` | 627 | `thr_create` | Create kernel thread |
| `0x274` | 628 | `thr_exit` | Exit thread |
| `0x275` | 629 | `thr_suspend` | Suspend thread |
| `0x276` | 630 | `thr_resume` | Resume thread |
| `0x286` | 646 | `kqueue` | Create event queue |
| `0x287` | 647 | `kevent` | Kernel event monitoring |
| `0x295` | 661 | `kexec` | PS4 kernel execution |
| `0x296` | 662 | `aio_multi_delete` | Delete multiple AIO requests |
| `0x297` | 663 | `aio_multi_wait` | Wait for multiple AIO requests |
| `0x298` | 664 | `aio_multi_poll` | Poll multiple AIO requests |
| `0x299` | 665 | `aio_multi_cancel` | Cancel multiple AIO requests |
| `0x29D` | 669 | `aio_submit_cmd` | Submit async I/O command |
