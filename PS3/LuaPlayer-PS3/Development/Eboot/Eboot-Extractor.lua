-- ELF extractor (from bin)
-- finds \x7FELF inside EBOOT.BIN and dumps from there

local usb
for _, root in ipairs{"/dev_usb000","/dev_usb001","/dev_usb002","/dev_usb003"} do
    local f = io.open(root .. "/.t","w")
    if f then f:close(); os.remove(root .. "/.t"); usb = root; break end
end
if not usb then error("No USB") end

local src_path = "/dev_hdd0/game/LUAP00001/USRDIR/EBOOT.BIN"
local log_path = usb .. "/elf_scan.txt"
local elf_out  = usb .. "/raw_elf.bin"

local log = io.open(log_path, "w")
log:setvbuf("no")
local function pr(...)
    for _, v in ipairs{...} do log:write(tostring(v)) end
    log:write("\n")
    log:flush()
end

pr("=== ELF Magic Scanner ===")
pr("Source: " .. src_path)

local src, err = io.open(src_path, "rb") or io.open(src_path, "r")
if not src then pr("ERROR: " .. tostring(err)); log:close(); return end

-- Read the file in chunks and look for the ELF magic
local magic = "\127ELF"   -- 0x7F 0x45 0x4C 0x46
local chunk_size = 64 * 1024   -- 64 KB
local offset = 0
local found_at = nil
local overlap = ""
while true do
    local data = src:read(chunk_size)
    if not data then break end
    local search_in = overlap .. data
    local pos = search_in:find(magic, 1, true)
    if pos then
        found_at = offset - #overlap + pos - 1   -- 0‑based file offset
        pr("ELF magic found at file offset 0x" .. string.format("%X", found_at))
        break
    end
    -- so .. it will keep last 3 bytes as overlap for next chunk
    overlap = #data >= 3 and data:sub(-3) or data
    offset = offset + #data
end

if not found_at then
    pr("ELF magic not found. The file may be fully encrypted or not a SELF with ELF inside.")
    src:close()
    log:close()
    return
end

-- extracts from found_at to end of file
src:seek("set", found_at)
local dst = io.open(elf_out, "wb") or io.open(elf_out, "w")
if not dst then pr("ERROR creating output"); src:close(); log:close(); return end

local total = 0
while true do
    local block = src:read(chunk_size)
    if not block then break end
    dst:write(block)
    total = total + #block
end
dst:close()
src:close()

pr("Extracted raw ELF: " .. elf_out)
pr(string.format("Bytes written: %d (%.2f MB)", total, total / 1048576))

local elf = io.open(elf_out, "rb") or io.open(elf_out, "r")
if elf then
    local m = elf:read(4)
    elf:close()
    if m == magic then
        pr("SUCCESS: Extracted file starts with ELF magic.")
    else
        pr("WARNING: Extracted file does NOT start with ELF. Encryption/compression likely present.")
    end
else
    pr("Could not verify output file.")
end

pr("\nDone.")
log:close()
