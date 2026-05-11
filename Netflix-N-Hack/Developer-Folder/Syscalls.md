# ![PlayStation](https://img.shields.io/badge/PlayStation-PS4%20%7C%20PS5-003791?style=for-the-badge&logo=playstation&logoColor=white) PS4 Syscall List
### Netflix n Hack / Lapse Research Findings

A compact reference of commonly observed PlayStation 4 syscalls used across:
- Userland research
- Homebrew
- Threading/runtime systems
- Memory management
- JIT environments
- Sandbox analysis
- Async I/O systems

---

# Core Process & File Syscalls

| ID | Name | Description |
|---|---|---|
| `#0` | `syscall` | Generic syscall wrapper |
| `#1` | `exit` | Process exit |
| `#3` | `read` | Read from file descriptor |
| `#4` | `write` | Write to file descriptor |
| `#5` | `open` | Open or create a file |
| `#6` | `close` | Close a file descriptor |
| `#10` | `unlink` | Remove a file |
| `#20` | `getpid` | Get process ID |
| `#24` | `getuid` | Get user ID |

---

# Signals & Process Control

| ID | Name | Description |
|---|---|---|
| `#25` | `kill` | Send signal to a process |
| `#37` | `kill` | Alternate signal interface |
| `#42` | `pipe` | Create a pipe |

---

# Memory Management

| ID | Name | Description |
|---|---|---|
| `#73` | `munmap` | Unmap memory |
| `#74` | `mprotect` | Change memory protection |
| `#477` | `mmap` | Map memory into process space |

---

# Networking

| ID | Name | Description |
|---|---|---|
| `#98` | `connect` | Connect a socket |
| `#118` | `getsockopt` | Get socket options |
| `#135` | `socketpair` | Create connected socket pair |

---

# Timing & Scheduling

| ID | Name | Description |
|---|---|---|
| `#240` | `nanosleep` | High-resolution sleep |
| `#331` | `sched_yield` | Yield CPU execution |

---

# Threading System

| ID | Name | Description |
|---|---|---|
| `#431` | `thr_exit` | Exit current thread |
| `#432` | `thr_self` | Get current thread ID |
| `#455` | `thr_new` | Create new thread |
| `#466` | `rtprio_thread` | Set thread realtime priority |

---

# CPU Affinity

| ID | Name | Description |
|---|---|---|
| `#487` | `cpuset_getaffinity` | Get CPU affinity mask |
| `#488` | `cpuset_setaffinity` | Set CPU affinity mask |

---

# JIT Shared Memory

| ID | Name | Description |
|---|---|---|
| `#533` | `jitshm_create` | Create JIT shared memory |
| `#534` | `jitshm_alias` | Alias JIT shared memory |

---

# Event Flag System

| ID | Name | Description |
|---|---|---|
| `#538` | `evf_create` | Create event flag |
| `#539` | `evf_delete` | Delete event flag |
| `#544` | `evf_set` | Set event flag |
| `#545` | `evf_clear` | Clear event flag |

---

# Sandbox & Runtime

| ID | Name | Description |
|---|---|---|
| `#585` | `is_in_sandbox` | Check sandbox status |
| `#591` | `dlsym` | Resolve runtime symbols |

---

# Advanced Thread Context Control

| ID | Name | Description |
|---|---|---|
| `#632` | `thr_suspend_ucontext` | Suspend thread using ucontext |
| `#633` | `thr_resume_ucontext` | Resume suspended thread |

---

# Kernel & Async I/O

| ID | Name | Description |
|---|---|---|
| `#661` | `kexec` | Execute in kernel mode |
| `#662` | `aio_multi_delete` | Delete async I/O requests |
| `#663` | `aio_multi_wait` | Wait for async I/O |
| `#664` | `aio_multi_poll` | Poll async I/O |
| `#666` | `aio_multi_cancel` | Cancel async I/O |
| `#669` | `aio_submit_cmd` | Submit async I/O command |

---

# Runtime Categories

| Category | Syscalls |
|---|---|
| File I/O | `read`, `write`, `open`, `close`, `unlink` |
| Memory | `mmap`, `munmap`, `mprotect` |
| Networking | `connect`, `getsockopt`, `socketpair` |
| Threading | `thr_new`, `thr_exit`, `thr_self` |
| Scheduling | `sched_yield`, `rtprio_thread` |
| JIT Runtime | `jitshm_create`, `jitshm_alias` |
| Synchronization | `evf_create`, `evf_set`, `evf_clear` |
| Sandbox | `is_in_sandbox` |
| Kernel Runtime | `kexec` |
| Async I/O | `aio_*` family |

---

# Notes

- The PS4 syscall layer is heavily derived from FreeBSD.
- Many runtime primitives map closely to FreeBSD kernel interfaces.
- Sony added several platform-specific syscalls for:
  - JIT memory
  - Event flags
  - Sandboxing
  - Async I/O
  - Kernel execution interfaces
- Thread and affinity syscalls are commonly used by:
  - Games
  - WebKit runtime
  - Homebrew loaders
  - Exploit chains
  - Multimedia systems

---

# Related Areas of Research

- FreeBSD syscall internals
- PS4 kernel architecture
- Userland runtime analysis
- JIT shared memory behavior
- Event flag synchronization
- Sandbox restrictions
- Async I/O scheduling
- Thread context switching
- CPU affinity systems
- WebKit runtime integration
