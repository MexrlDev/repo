-- Standalone syscall test for Remote Lua Loader
-- Tests getpid, getuid, open /dev/null, dup, and close

function main()
    print("[*] Running syscall test...")
    
    -- Resolve syscalls
    syscall.resolve({
        getpid = 20,   -- 0x14
        getuid = 24,   -- 0x18
        open = 5,      -- 0x05
        close = 6,     -- 0x06
        dup = 41,      -- 0x29
    })
    
    -- 1. getpid
    local pid = syscall.getpid():tonumber()
    print(string.format("[+] getpid() = %d", pid))
    
    -- 2. getuid
    local uid = syscall.getuid():tonumber()
    print(string.format("[+] getuid() = %d", uid))
    
    -- 3. open /dev/null (O_RDONLY = 0)
    local path = "/dev/null"
    local fd = syscall.open(path, 0):tonumber()
    if fd == -1 then
        print("[-] open(/dev/null) failed")
        send_ps_notification("open failed")
        return
    end
    print(string.format("[*] Opened /dev/null, fd = %d", fd))
    
    -- 4. dup on valid fd
    local new_fd = syscall.dup(fd):tonumber()
    if new_fd == -1 then
        print(string.format("[-] dup(%d) failed", fd))
    else
        print(string.format("[+] dup(%d) = %d", fd, new_fd))
        syscall.close(new_fd)
    end
    
    -- Close original fd
    syscall.close(fd)
    print("[*] Syscall test completed successfully")
    send_ps_notification("Syscall test OK")
end

-- Run with error handling
local ok, err = pcall(main)
if not ok then
    print("Error: " .. tostring(err))
    send_ps_notification("Syscall test error")
end
