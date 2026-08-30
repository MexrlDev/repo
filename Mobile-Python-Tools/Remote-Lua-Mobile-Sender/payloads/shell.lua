-- shell.lua
-- Interactive command shell over TCP
-- oh mexrldev.... oh mexrldev...

-- Configuration
LISTEN_PORT = 9027
PROMPT = "RLL> "
BANNER = [[
Welcome to Remote Lua Loader Shell
Type 'help' for commands.
]]

-- Resolve additional syscalls if not already present
local function resolve_additional_syscalls()
    local needed = {
        stat = 188,
        getdents = 272,
        chdir = 124,
        getcwd = 139,
        getsockname = 32,
    }
    for name, num in pairs(needed) do
        if not syscall[name] then
            -- try to resolve; ignore errors (some may not be available)
            local ok, err = pcall(function()
                syscall.resolve({ [name] = num })
            end)
            if not ok then
                -- print warning but continue
                print("Warning: could not resolve " .. name .. " (" .. tostring(err) .. ")")
            end
        end
    end
end

-- Helper: send string to client
local function send_str(fd, s)
    if s then
        syscall.write(fd, s, #s)
    end
end

-- Helper: read a line from client (blocking)
local function read_line(fd)
    local buf = memory.alloc(256)
    local pos = 0
    while true do
        local n = syscall.read(fd, buf + pos, 1):tonumber()
        if n <= 0 then break end
        local c = memory.read_byte(buf + pos):tonumber()
        if c == 0x0a then -- newline
            break
        elseif c == 0x0d then -- carriage return, skip
            -- ignore
        else
            pos = pos + 1
        end
    end
    if pos == 0 then return "" end
    return memory.read_buffer(buf, pos)
end

-- Command implementations

-- ls: list directory
local function cmd_ls(args, fd, cwd)
    local path = args[1] or "."
    if path:sub(1,1) ~= "/" then
        path = cwd .. "/" .. path
    end
    local dir_fd = syscall.open(path, 0, 0):tonumber()
    if dir_fd < 0 then
        send_str(fd, "Error: cannot open directory\n")
        return
    end
    local buf = memory.alloc(4096)
    while true do
        local nread = syscall.getdents(dir_fd, buf, 4096):tonumber()
        if nread <= 0 then break end
        local entry = buf
        local end_ptr = buf + nread
        while entry < end_ptr do
            local reclen = memory.read_word(entry + 0x4):tonumber()
            if reclen == 0 then break end
            local namlen = memory.read_byte(entry + 0x7):tonumber()
            local name = memory.read_buffer(entry + 0x8, namlen)
            if name ~= "." and name ~= ".." then
                -- stat for type/size
                local fullpath = path
                if path ~= "/" then fullpath = fullpath .. "/" end
                fullpath = fullpath .. name
                local st = memory.alloc(120)
                if syscall.stat(fullpath, st):tonumber() == 0 then
                    local mode = memory.read_word(st + 8):tonumber()
                    local size = memory.read_qword(st + 72):tonumber()
                    local typechar = ""
                    if bit32.band(mode, 0x4000) ~= 0 then typechar = "d"
                    elseif bit32.band(mode, 0x8000) ~= 0 then typechar = "-" end
                    send_str(fd, string.format("%s %10d  %s\n", typechar, size, name))
                else
                    send_str(fd, "?         ?  " .. name .. "\n")
                end
            end
            entry = entry + reclen
        end
    end
    syscall.close(dir_fd)
end

-- cat: print file
local function cmd_cat(args, fd, cwd)
    if not args[1] then send_str(fd, "Usage: cat <file>\n") return end
    local path = args[1]
    if path:sub(1,1) ~= "/" then path = cwd .. "/" .. path end
    local f = syscall.open(path, 0, 0):tonumber()
    if f < 0 then send_str(fd, "Error: cannot open file\n") return end
    local buf = memory.alloc(4096)
    while true do
        local n = syscall.read(f, buf, 4096):tonumber()
        if n <= 0 then break end
        syscall.write(fd, buf, n)
    end
    syscall.close(f)
end

-- pwd
local function cmd_pwd(args, fd, cwd)
    send_str(fd, cwd .. "\n")
end

-- cd
local function cmd_cd(args, fd, cwd)
    if not args[1] then send_str(fd, "Usage: cd <dir>\n") return cwd end
    local newpath = args[1]
    if newpath:sub(1,1) ~= "/" then newpath = cwd .. "/" .. newpath end
    if syscall.chdir(newpath):tonumber() == 0 then
        local buf = memory.alloc(1024)
        local ret = syscall.getcwd(buf, 1024):tonumber()
        if ret ~= 0 then
            return memory.read_buffer(buf, ret)
        end
    end
    send_str(fd, "Error: cannot change directory\n")
    return cwd
end

-- ps: process list
local function cmd_ps(args, fd, cwd)
    -- if kernel primitives available, use allproc
    if is_jailbroken() and kernel and kernel.read_qword and kernel.addr and kernel.addr.allproc then
        send_str(fd, "PID      NAME\n")
        local proc = kernel.read_qword(kernel.addr.allproc)
        while proc ~= uint64(0) do
            local pid = kernel.read_dword(proc + kernel_offset.PROC_PID):tonumber()
            local name = kernel.read_null_terminated_string(proc + kernel_offset.PROC_COMM)
            if name then
                send_str(fd, string.format("%-8d %s\n", pid, name))
            end
            proc = kernel.read_qword(proc + 0x0) -- le_next
        end
    else
        local pid = syscall.getpid():tonumber()
        send_str(fd, string.format("PID: %d\n", pid))
        send_str(fd, "(Kernel R/W not available, full process list unavailable)\n")
    end
end

-- read memory (user space)
local function cmd_read(args, fd, cwd)
    if not args[1] then send_str(fd, "Usage: read <addr> [size]\n") return end
    local addr = uint64(args[1])
    local size = tonumber(args[2]) or 16
    if size > 4096 then size = 4096 end
    local data = memory.read_buffer(addr:tonumber(), size)
    if not data then
        send_str(fd, "Error: cannot read memory\n")
        return
    end
    local hex = bin_to_hex(data)
    local ascii = data:gsub("[^%w%p]", ".")
    send_str(fd, string.format("%s: %s  %s\n", hex(addr), hex:sub(1, size*2), ascii:sub(1, size)))
end

-- write memory (user space)
local function cmd_write(args, fd, cwd)
    if not args[1] or not args[2] then
        send_str(fd, "Usage: write <addr> <hexstring>\n")
        return
    end
    local addr = uint64(args[1])
    local hexstr = args[2]:gsub("%s+", "")
    if #hexstr % 2 ~= 0 then
        send_str(fd, "Error: hex string must have even length\n")
        return
    end
    local data = hex_to_binary(hexstr)
    memory.write_buffer(addr:tonumber(), data)
    send_str(fd, "Written " .. #data .. " bytes\n")
end

-- info
local function cmd_info(args, fd, cwd)
    local jailbroken = is_jailbroken() and "yes" or "no"
    local str = string.format(
        "Platform: %s\nFirmware: %s\nGame: %s\nJailbroken: %s\n",
        PLATFORM, FW_VERSION, game_name or "unknown", jailbroken
    )
    send_str(fd, str)
end

-- help
local function cmd_help(args, fd, cwd)
    local help_text = [[
Available commands:
  ls [path]          - list directory
  cat <file>         - print file contents
  pwd                - print current working directory
  cd <dir>           - change directory
  ps                 - list processes
  read <addr> [size] - read memory (user space)
  write <addr> <hex> - write memory (user space)
  info               - show system information
  help               - show this help
  exit               - close connection
]]
    send_str(fd, help_text)
end

-- Main shell loop
local function handle_client(fd)
    send_str(fd, BANNER)
    local cwd = syscall.getcwd(memory.alloc(1024), 1024):tonumber()
    if cwd == 0 then cwd = "/" else cwd = memory.read_null_terminated_string(cwd) end

    while true do
        send_str(fd, PROMPT)
        local line = read_line(fd)
        if line == "" then break end
        -- parse arguments
        local args = {}
        for token in line:gmatch("%S+") do
            table.insert(args, token)
        end
        if #args > 0 then
            local cmd = args[1]
            table.remove(args, 1)

            if cmd == "ls" then
                cmd_ls(args, fd, cwd)
            elseif cmd == "cat" then
                cmd_cat(args, fd, cwd)
            elseif cmd == "pwd" then
                cmd_pwd(args, fd, cwd)
            elseif cmd == "cd" then
                local newcwd = cmd_cd(args, fd, cwd)
                if newcwd then cwd = newcwd end
            elseif cmd == "ps" then
                cmd_ps(args, fd, cwd)
            elseif cmd == "read" then
                cmd_read(args, fd, cwd)
            elseif cmd == "write" then
                cmd_write(args, fd, cwd)
            elseif cmd == "info" then
                cmd_info(args, fd, cwd)
            elseif cmd == "help" then
                cmd_help(args, fd, cwd)
            elseif cmd == "exit" then
                send_str(fd, "Goodbye\n")
                break
            else
                send_str(fd, "Unknown command. Type 'help'.\n")
            end
        end
    end
    syscall.close(fd)
end

-- Start TCP server
local function start_shell()
    resolve_additional_syscalls()

    local enable = memory.alloc(4)
    memory.write_dword(enable, 1)
    local sockaddr_in = memory.alloc(16)
    local addrlen = memory.alloc(8)
    memory.write_dword(addrlen, 16)

    local sock_fd = syscall.socket(AF_INET, SOCK_STREAM, 0):tonumber()
    if sock_fd < 0 then
        print("socket() error: " .. get_error_string())
        return
    end

    syscall.setsockopt(sock_fd, SOL_SOCKET, SO_REUSEADDR, enable, 4)

    local function htons(port)
        return bit32.bor(bit32.lshift(port, 8), bit32.rshift(port, 8)) % 0x10000
    end

    memory.write_byte(sockaddr_in + 1, AF_INET)
    memory.write_word(sockaddr_in + 2, htons(LISTEN_PORT))
    memory.write_dword(sockaddr_in + 4, INADDR_ANY)

    if syscall.bind(sock_fd, sockaddr_in, 16):tonumber() < 0 then
        print("bind() error: " .. get_error_string())
        syscall.close(sock_fd)
        return
    end

    if syscall.listen(sock_fd, 3):tonumber() < 0 then
        print("listen() error: " .. get_error_string())
        syscall.close(sock_fd)
        return
    end

    local current_ip = get_current_ip()
    local network_str = current_ip and string.format("%s:%d", current_ip, LISTEN_PORT) or ("port " .. LISTEN_PORT)
    local console_model = get_console_model()
    notify(string.format("Shell listening on %s", network_str))
    print("[+] Shell listening on " .. network_str)

    while true do
        memory.write_dword(addrlen, 16)
        local client_fd = syscall.accept(sock_fd, sockaddr_in, addrlen):tonumber()
        if client_fd < 0 then
            print("accept() error: " .. get_error_string())
            break
        end
        print("[+] Shell client connected")
        handle_client(client_fd)
    end
    syscall.close(sock_fd)
end

-- Entry point
function main()
    start_shell()
end

main()
