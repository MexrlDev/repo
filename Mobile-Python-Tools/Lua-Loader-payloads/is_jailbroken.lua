-- check console JB for Remote Lua Loader
-- Uses setuid(0) to test root privileges

function main()
    print("Running jailbreak check...")
    
    -- Resolve syscalls
    syscall.resolve({
        getuid = 0x18,
        setuid = 0x17,
    })
    
    local uid_before = syscall.getuid():tonumber()
    print(string.format("[*] UID before setuid: %d", uid_before))
    
    local ret = syscall.setuid(0):tonumber()
    if ret == -1 then
        print("[*] setuid(0) failed (errno not directly available)")
    else
        print(string.format("[*] setuid(0) returned %d", ret))
    end
    
    local uid_after = syscall.getuid():tonumber()
    print(string.format("[*] UID after setuid: %d", uid_after))
    
    local jailbroken = (uid_after == 0)
    print(string.format("[+] Jailbroken: %s", jailbroken and "YES" or "NO"))
    
    -- System notification (PS4/PS5)
    if jailbroken then
        send_ps_notification("Jailbroken!")
    else
        send_ps_notification("Not jailbroken")
    end
    
    return jailbroken
end

-- Run with error handling
local ok, err = pcall(main)
if not ok then
    print("Error: " .. tostring(err))
    send_ps_notification("Error in jailbreak check")
end
