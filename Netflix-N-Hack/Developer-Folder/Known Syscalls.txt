PS4 Syscall List (from Netflix n Hack / lapse findings)
=========================================================

  #0  syscall                Generic syscall wrapper
  #1  exit                   Process exit
  #3  read                   Read from file descriptor
  #4  write                  Write to file descriptor
  #5  open                   Open or create a file
  #6  close                  Close a file descriptor
 #10  unlink                 Remove a file
 #20  getpid                 Get process ID
 #24  getuid                 Get user ID
 #25  kill                   Send signal to a process
 #37  kill                   Send signal to a process (alternate)
 #42  pipe                   Create a pipe
 #73  munmap                 Unmap memory
 #74  mprotect               Set memory protection
 #98  connect                Connect a socket
#118  getsockopt             Get socket options
#135  socketpair             Create a pair of sockets
#240  nanosleep              Sleep for nanoseconds
#331  sched_yield            Yield CPU
#431  thr_exit               Exit current thread
#432  thr_self               Get thread ID
#455  thr_new                Create new thread
#466  rtprio_thread          Set thread real-time priority
#477  mmap                   Map memory
#487  cpuset_getaffinity     Get CPU affinity mask
#488  cpuset_setaffinity     Set CPU affinity mask
#533  jitshm_create          Create JIT shared memory
#534  jitshm_alias           Alias JIT shared memory
#538  evf_create             Create event flag
#539  evf_delete             Delete event flag
#544  evf_set                Set event flag
#545  evf_clear              Clear event flag
#585  is_in_sandbox          Check if in sandbox
#591  dlsym                  Look up a symbol
#632  thr_suspend_ucontext   Suspend thread (ucontext)
#633  thr_resume_ucontext    Resume thread (ucontext)
#661  kexec                  Execute in kernel mode
#662  aio_multi_delete       Delete AIO requests
#663  aio_multi_wait         Wait for AIO requests
#664  aio_multi_poll         Poll AIO requests
#666  aio_multi_cancel       Cancel AIO requests
#669  aio_submit_cmd         Submit AIO command
