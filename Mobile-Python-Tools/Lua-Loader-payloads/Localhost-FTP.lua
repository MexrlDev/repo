-- FTP Server for Remote Lua Loader
-- Binds to 0.0.0.0:1337, shows IP from local interface, but not a real ftp since only works on 127..

-- Resolve required syscalls
syscall.resolve({
    read = 0x3,
    write = 0x4,
    open = 0x5,
    close = 0x6,
    socket = 0x61,
    bind = 0x68,
    listen = 0x6a,
    accept = 0x1e,
    connect = 0x62,
    setsockopt = 0x69,
    getsockname = 0x32,
    getpeername = 0x1f,
    stat = 0xbc,
    unlink = 0xa,
    rename = 0x80,
    mkdir = 0x88,
    rmdir = 0x89,
    getdents = 0x110,
    getuid = 0x18,
})

-- Constants
AF_INET = 2
SOCK_STREAM = 1
SOL_SOCKET = 0xFFFF
SO_REUSEADDR = 4
O_RDONLY = 0
O_WRONLY = 1
O_CREAT = 0x200
S_IFMT = 0xF000
S_IFDIR = 0x4000
S_IFREG = 0x8000
MAX_CLIENTS = 4
CHUNK_SIZE = 8192
MODE_666 = 438
MODE_777 = 511
PORT = 1337

-- Helper: htons (also works as ntohs for 16-bit)
function htons(port)
    return bit32.bor(bit32.lshift(port, 8), bit32.rshift(port, 8)) % 0x10000
end

-- Helper: get local IP (simplified but works on most setups)
function get_local_ip()
    local udp_fd = syscall.socket(AF_INET, 2, 0):tonumber() -- SOCK_DGRAM
    if udp_fd < 0 then return "127.0.0.1" end

    local addr = memory.alloc(16)
    memory.write_byte(addr + 1, AF_INET)
    memory.write_word(addr + 2, htons(53))
    memory.write_dword(addr + 4, 0x01010101) -- 1.1.1.1

    syscall.connect(udp_fd, addr, 16)

    local local_addr = memory.alloc(16)
    local len = memory.alloc(4)
    memory.write_dword(len, 16)

    local ret = syscall.getsockname(udp_fd, local_addr, len)
    syscall.close(udp_fd)

    if ret:tonumber() ~= 0 then return "127.0.0.1" end

    local ip = memory.read_dword(local_addr + 4):tonumber()
    local b1 = bit32.band(bit32.rshift(ip, 24), 0xFF)
    local b2 = bit32.band(bit32.rshift(ip, 16), 0xFF)
    local b3 = bit32.band(bit32.rshift(ip, 8), 0xFF)
    local b4 = bit32.band(ip, 0xFF)

    if b1 == 0 and b2 == 0 and b3 == 0 and b4 == 0 then
        return "127.0.0.1"
    end
    return string.format("%d.%d.%d.%d", b1, b2, b3, b4)
end

-- Helper: create TCP socket
function new_tcp_socket()
    local fd = syscall.socket(AF_INET, SOCK_STREAM, 0):tonumber()
    if fd < 0 then
        print("socket() failed")
        return nil
    end
    return fd
end

-- Helper: send FTP response
function send_response(client_fd, code, message)
    local resp = code .. " " .. message .. "\r\n"
    syscall.write(client_fd, resp, #resp)
end

-- Persistent buffer for recv_line
local recv_buf = ""

-- Helper: read one line (CRLF terminated) from client
function read_line(client_fd)
    while true do
        local pos = string.find(recv_buf, "\r\n", 1, true)
        if pos then
            local line = string.sub(recv_buf, 1, pos - 1)
            recv_buf = string.sub(recv_buf, pos + 2)
            return line
        end

        local buf = memory.alloc(1024)
        local n = syscall.read(client_fd, buf, 1024):tonumber()
        if n <= 0 then
            return nil
        end
        local chunk = memory.read_buffer(buf, n)
        recv_buf = recv_buf .. chunk
    end
end

-- Helper: build absolute path
function build_path(cwd, path)
    local result
    if string.sub(path, 1, 1) == "/" then
        result = path
    else
        if cwd == "/" then
            result = "/" .. path
        else
            result = cwd .. "/" .. path
        end
    end
    while #result > 1 and string.sub(result, -1) == "/" do
        result = string.sub(result, 1, -2)
    end
    while string.find(result, "//") do
        result = string.gsub(result, "//", "/")
    end
    return result
end

-- Helper: format file mode string (like ls -l)
function format_file_mode(mode)
    local str = ""
    if bit32.band(mode, S_IFMT) == S_IFDIR then
        str = str .. "d"
    else
        str = str .. "-"
    end
    str = str .. (bit32.band(mode, 0x100) ~= 0 and "r" or "-")
    str = str .. (bit32.band(mode, 0x080) ~= 0 and "w" or "-")
    str = str .. (bit32.band(mode, 0x040) ~= 0 and "x" or "-")
    str = str .. (bit32.band(mode, 0x020) ~= 0 and "r" or "-")
    str = str .. (bit32.band(mode, 0x010) ~= 0 and "w" or "-")
    str = str .. (bit32.band(mode, 0x008) ~= 0 and "x" or "-")
    str = str .. (bit32.band(mode, 0x004) ~= 0 and "r" or "-")
    str = str .. (bit32.band(mode, 0x002) ~= 0 and "w" or "-")
    str = str .. (bit32.band(mode, 0x001) ~= 0 and "x" or "-")
    return str
end

-- Helper: create passive mode socket
function create_pasv_socket()
    local data_fd = new_tcp_socket()
    if not data_fd then return nil end
    local enable = memory.alloc(4)
    memory.write_dword(enable, 1)
    syscall.setsockopt(data_fd, SOL_SOCKET, SO_REUSEADDR, enable, 4)
    local addr = memory.alloc(16)
    memory.write_dword(addr, 0)
    memory.write_byte(addr + 1, AF_INET)
    memory.write_word(addr + 2, 0)
    memory.write_dword(addr + 4, 0)
    if syscall.bind(data_fd, addr, 16):tonumber() ~= 0 then
        syscall.close(data_fd)
        return nil
    end
    if syscall.listen(data_fd, 1):tonumber() ~= 0 then
        syscall.close(data_fd)
        return nil
    end
    local actual_addr = memory.alloc(16)
    local addrlen = memory.alloc(4)
    memory.write_dword(addrlen, 16)
    syscall.getsockname(data_fd, actual_addr, addrlen)
    local port_raw = memory.read_word(actual_addr + 2):tonumber()
    local port = htons(port_raw)
    return { fd = data_fd, port = port }
end

-- Helper: accept data connection
function accept_data_connection(pasv_fd)
    local client_fd = syscall.accept(pasv_fd, 0, 0):tonumber()
    if client_fd < 0 then return -1 end
    return client_fd
end

-- Command handlers (same as before, fully included)
function handle_user(client_fd, args, state)
    send_response(client_fd, "331", "Username OK, any password accepted")
end

function handle_pass(client_fd, args, state)
    send_response(client_fd, "230", "Login successful")
end

function handle_syst(client_fd, args, state)
    send_response(client_fd, "215", "UNIX Type: L8")
end

function handle_pwd(client_fd, args, state)
    send_response(client_fd, "257", '"' .. state.cwd .. '" is current directory')
end

function handle_cwd(client_fd, args, state)
    if not args or args == "" then
        send_response(client_fd, "500", "Syntax error")
        return
    end
    local new_path
    if args == "/" then
        new_path = "/"
    elseif args == ".." then
        if state.cwd == "/" then
            new_path = "/"
        else
            local last = string.find(state.cwd, "/[^/]*$")
            if last then
                new_path = string.sub(state.cwd, 1, last - 1)
            else
                new_path = "/"
            end
        end
    else
        new_path = build_path(state.cwd, args)
    end
    local statbuf = memory.alloc(144)
    local ret = syscall.stat(new_path, statbuf):tonumber()
    if ret ~= 0 then
        send_response(client_fd, "550", "Directory not found")
        return
    end
    local mode = memory.read_word(statbuf + 8):tonumber()
    if bit32.band(mode, S_IFMT) ~= S_IFDIR then
        send_response(client_fd, "550", "Not a directory")
        return
    end
    state.cwd = new_path
    send_response(client_fd, "250", "Directory changed")
end

function handle_cdup(client_fd, args, state)
    handle_cwd(client_fd, "..", state)
end

function handle_type(client_fd, args, state)
    state.type = string.upper(args)
    send_response(client_fd, "200", "Type set to " .. state.type)
end

function handle_pasv(client_fd, args, state)
    local pasv = create_pasv_socket()
    if not pasv then
        send_response(client_fd, "425", "Cannot open passive connection")
        return
    end
    state.pasv_fd = pasv.fd
    state.pasv_port = pasv.port

    local peer_addr = memory.alloc(16)
    local addrlen = memory.alloc(4)
    memory.write_dword(addrlen, 16)
    syscall.getpeername(client_fd, peer_addr, addrlen)
    local ip = memory.read_dword(peer_addr + 4):tonumber()
    local b1 = bit32.band(bit32.rshift(ip, 24), 0xFF)
    local b2 = bit32.band(bit32.rshift(ip, 16), 0xFF)
    local b3 = bit32.band(bit32.rshift(ip, 8), 0xFF)
    local b4 = bit32.band(ip, 0xFF)

    local p1 = bit32.rshift(pasv.port, 8)
    local p2 = bit32.band(pasv.port, 0xFF)
    send_response(client_fd, "227", "Entering Passive Mode (" .. b1 .. "," .. b2 .. "," .. b3 .. "," .. b4 .. "," .. p1 .. "," .. p2 .. ")")
end

function handle_list(client_fd, args, state)
    if not state.pasv_fd or state.pasv_fd < 0 then
        send_response(client_fd, "425", "Use PASV first")
        return
    end
    local path = state.cwd
    send_response(client_fd, "150", "Opening ASCII mode data connection for file list")
    local data_fd = accept_data_connection(state.pasv_fd)
    if data_fd < 0 then
        send_response(client_fd, "426", "Connection closed; transfer aborted")
        syscall.close(state.pasv_fd)
        state.pasv_fd = -1
        return
    end
    local dir_fd = syscall.open(path, O_RDONLY, 0):tonumber()
    if dir_fd >= 0 then
        local buf = memory.alloc(1024)
        while true do
            local bytes = syscall.getdents(dir_fd, buf, 1024):tonumber()
            if bytes <= 0 then break end
            local offset = 0
            while offset < bytes do
                local reclen = memory.read_word(buf + offset + 4):tonumber()
                local d_type = memory.read_byte(buf + offset + 6)
                local namlen = memory.read_byte(buf + offset + 7)
                local name = ""
                for i = 0, namlen - 1 do
                    name = name .. string.char(memory.read_byte(buf + offset + 8 + i))
                end
                if name ~= "." and name ~= ".." then
                    local mode = (d_type == 4 and S_IFDIR or S_IFREG)
                    local line = format_file_mode(mode) .. " 1 root root 4096 Jan 1 2024 " .. name .. "\r\n"
                    syscall.write(data_fd, line, #line)
                end
                offset = offset + reclen
            end
        end
        syscall.close(dir_fd)
    end
    syscall.close(data_fd)
    syscall.close(state.pasv_fd)
    state.pasv_fd = -1
    send_response(client_fd, "226", "Transfer complete")
end

function handle_retr(client_fd, args, state)
    if not state.pasv_fd or state.pasv_fd < 0 then
        send_response(client_fd, "425", "Use PASV first")
        return
    end
    local path = build_path(state.cwd, args)
    local file_fd = syscall.open(path, O_RDONLY, 0):tonumber()
    if file_fd < 0 then
        send_response(client_fd, "550", "File not found")
        syscall.close(state.pasv_fd)
        state.pasv_fd = -1
        return
    end
    send_response(client_fd, "150", "Opening BINARY mode data connection")
    local data_fd = accept_data_connection(state.pasv_fd)
    if data_fd < 0 then
        send_response(client_fd, "426", "Connection closed; transfer aborted")
        syscall.close(file_fd)
        syscall.close(state.pasv_fd)
        state.pasv_fd = -1
        return
    end
    local buf = memory.alloc(CHUNK_SIZE)
    while true do
        local bytes = syscall.read(file_fd, buf, CHUNK_SIZE):tonumber()
        if bytes <= 0 then break end
        syscall.write(data_fd, buf, bytes)
    end
    syscall.close(file_fd)
    syscall.close(data_fd)
    syscall.close(state.pasv_fd)
    state.pasv_fd = -1
    send_response(client_fd, "226", "Transfer complete")
end

function handle_stor(client_fd, args, state)
    if not state.pasv_fd or state.pasv_fd < 0 then
        send_response(client_fd, "425", "Use PASV first")
        return
    end
    if not args or args == "" then
        send_response(client_fd, "553", "Invalid filename")
        syscall.close(state.pasv_fd)
        state.pasv_fd = -1
        return
    end
    local path = build_path(state.cwd, args)
    local statbuf = memory.alloc(144)
    if syscall.stat(path, statbuf):tonumber() == 0 then
        local mode = memory.read_word(statbuf + 8):tonumber()
        if bit32.band(mode, S_IFMT) == S_IFDIR then
            send_response(client_fd, "550", "Cannot overwrite directory")
            syscall.close(state.pasv_fd)
            state.pasv_fd = -1
            return
        end
        syscall.unlink(path)
    end
    local file_fd = syscall.open(path, bit32.bor(O_WRONLY, O_CREAT), MODE_666):tonumber()
    if file_fd < 0 then
        send_response(client_fd, "550", "Cannot create file")
        syscall.close(state.pasv_fd)
        state.pasv_fd = -1
        return
    end
    send_response(client_fd, "150", "Opening BINARY mode data connection")
    local data_fd = accept_data_connection(state.pasv_fd)
    if data_fd < 0 then
        send_response(client_fd, "426", "Connection closed; transfer aborted")
        syscall.close(file_fd)
        syscall.close(state.pasv_fd)
        state.pasv_fd = -1
        return
    end
    local buf = memory.alloc(CHUNK_SIZE)
    while true do
        local bytes = syscall.read(data_fd, buf, CHUNK_SIZE):tonumber()
        if bytes <= 0 then break end
        syscall.write(file_fd, buf, bytes)
    end
    syscall.close(file_fd)
    syscall.close(data_fd)
    syscall.close(state.pasv_fd)
    state.pasv_fd = -1
    send_response(client_fd, "226", "Transfer complete")
end

function handle_dele(client_fd, args, state)
    local path = build_path(state.cwd, args)
    if syscall.unlink(path):tonumber() == 0 then
        send_response(client_fd, "250", "File deleted")
    else
        send_response(client_fd, "550", "Delete failed")
    end
end

function handle_mkd(client_fd, args, state)
    local path = build_path(state.cwd, args)
    if syscall.mkdir(path, MODE_777):tonumber() == 0 then
        send_response(client_fd, "257", '"' .. path .. '" directory created')
    else
        send_response(client_fd, "550", "Create directory failed")
    end
end

function handle_rmd(client_fd, args, state)
    local path = build_path(state.cwd, args)
    if syscall.rmdir(path):tonumber() == 0 then
        send_response(client_fd, "250", "Directory removed")
    else
        send_response(client_fd, "550", "Remove directory failed")
    end
end

function handle_rnfr(client_fd, args, state)
    state.rename_from = build_path(state.cwd, args)
    send_response(client_fd, "350", "Ready for RNTO")
end

function handle_rnto(client_fd, args, state)
    if not state.rename_from then
        send_response(client_fd, "503", "Bad sequence of commands")
        return
    end
    local path_to = build_path(state.cwd, args)
    if syscall.rename(state.rename_from, path_to):tonumber() == 0 then
        send_response(client_fd, "250", "Rename successful")
    else
        send_response(client_fd, "550", "Rename failed")
    end
    state.rename_from = nil
end

function handle_size(client_fd, args, state)
    local path = build_path(state.cwd, args)
    local statbuf = memory.alloc(144)
    if syscall.stat(path, statbuf):tonumber() == 0 then
        local size = memory.read_qword(statbuf + 48):tonumber()
        send_response(client_fd, "213", tostring(size))
    else
        send_response(client_fd, "550", "Could not get file size")
    end
end

function handle_noop(client_fd, args, state)
    send_response(client_fd, "200", "OK")
end

function handle_feat(client_fd, args, state)
    local resp = "211-Features:\r\n PASV\r\n SIZE\r\n UTF8\r\n211 End\r\n"
    syscall.write(client_fd, resp, #resp)
end

function handle_quit(client_fd, args, state)
    send_response(client_fd, "221", "Goodbye")
end

function handle_mdtm(client_fd, args, state)
    local path = build_path(state.cwd, args)
    local statbuf = memory.alloc(144)
    if syscall.stat(path, statbuf):tonumber() == 0 then
        send_response(client_fd, "213", "20240101000000")
    else
        send_response(client_fd, "550", "File not found")
    end
end

-- Main client handler
function handle_client(client_fd)
    local state = {
        cwd = "/",
        type = "A",
        pasv_fd = -1,
        pasv_port = -1,
        rename_from = nil,
    }
    send_response(client_fd, "220", "PS4 FTP Server Ready")
    while true do
        local line = read_line(client_fd)
        if not line then break end
        local parts = {}
        for token in string.gmatch(line, "%S+") do
            table.insert(parts, token)
        end
        if #parts == 0 then break end
        local cmd = string.upper(parts[1])
        local args = table.concat(parts, " ", 2)
        local handlers = {
            USER = handle_user,
            PASS = handle_pass,
            SYST = handle_syst,
            PWD = handle_pwd,
            CWD = handle_cwd,
            CDUP = handle_cdup,
            TYPE = handle_type,
            PASV = handle_pasv,
            LIST = handle_list,
            RETR = handle_retr,
            STOR = handle_stor,
            DELE = handle_dele,
            MKD = handle_mkd, XMKD = handle_mkd,
            RMD = handle_rmd, XRMD = handle_rmd,
            RNFR = handle_rnfr,
            RNTO = handle_rnto,
            SIZE = handle_size,
            NOOP = handle_noop,
            FEAT = handle_feat,
            MDTM = handle_mdtm,
            QUIT = handle_quit,
        }
        local handler = handlers[cmd]
        if handler then
            handler(client_fd, args, state)
            if cmd == "QUIT" then break end
        else
            send_response(client_fd, "502", "Command not implemented")
        end
    end
    if state.pasv_fd >= 0 then syscall.close(state.pasv_fd) end
    syscall.close(client_fd)
end

-- Main server loop
function start_ftp_server()
    local server_fd = new_tcp_socket()
    if not server_fd then
        print("Failed to create server socket")
        return
    end

    local enable = memory.alloc(4)
    memory.write_dword(enable, 1)
    syscall.setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, enable, 4)

    local addr = memory.alloc(16)
    memory.write_dword(addr, 0)
    memory.write_byte(addr + 1, AF_INET)
    memory.write_word(addr + 2, htons(PORT))
    memory.write_dword(addr + 4, 0) -- INADDR_ANY

    if syscall.bind(server_fd, addr, 16):tonumber() ~= 0 then
        print("bind() failed on port " .. PORT)
        syscall.close(server_fd)
        return
    end

    local actual_addr = memory.alloc(16)
    local addrlen = memory.alloc(4)
    memory.write_dword(addrlen, 16)
    syscall.getsockname(server_fd, actual_addr, addrlen)
    local port_raw = memory.read_word(actual_addr + 2):tonumber()
    local actual_port = htons(port_raw)

    if syscall.listen(server_fd, MAX_CLIENTS):tonumber() ~= 0 then
        print("listen() failed")
        syscall.close(server_fd)
        return
    end

    local ip = get_local_ip()
    print("FTP Server started on " .. ip .. ":" .. actual_port)
    send_ps_notification("FTP Server: " .. ip .. ":" .. actual_port)

    while true do
        local client_fd = syscall.accept(server_fd, 0, 0):tonumber()
        if client_fd >= 0 then
            handle_client(client_fd)
        end
    end
end

-- Run
local ok, err = pcall(start_ftp_server)
if not ok then
    print("FTP Server error: " .. tostring(err))
    send_ps_notification("FTP Server error")
end
