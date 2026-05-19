-- PS3 elf extractor
local usb
for _, root in ipairs{"/dev_usb000","/dev_usb001","/dev_usb002","/dev_usb003"} do
    local f = io.open(root .. "/.t","w")
    if f then f:close(); os.remove(root .. "/.t"); usb = root; break end
end
if not usb then error("No USB") end

local src_path = "/dev_hdd0/game/LUAP00001/USRDIR/EBOOT.BIN"
local log_path = usb .. "/Elf-Offsets.txt"
local elf_path = usb .. "/ELV_dump.elf"

local log = io.open(log_path, "w")
log:setvbuf("no")
local function pr(...)
    local args = {...}
    for _, v in ipairs(args) do log:write(tostring(v)) end
    log:write("\n")
    log:flush()
end

-- Helpers to read little-endian integers
local function read_u8(f)
    return f:read(1):byte()
end
local function read_u16(f)
    local b1,b2 = f:read(2):byte(1,2)
    return b1 + b2*256
end
local function read_u32(f)
    local b1,b2,b3,b4 = f:read(4):byte(1,4)
    return b1 + b2*256 + b3*65536 + b4*16777216
end
local function read_u64(f)
    local lo = read_u32(f)
    local hi = read_u32(f)
    return lo + hi * 4294967296
end

pr("=== SELF Parser ===")
pr("File: " .. src_path)
pr("Date: " .. os.date())

-- Open source
local src, err = io.open(src_path, "rb") or io.open(src_path, "r")
if not src then pr("ERROR: " .. tostring(err)); log:close(); return end
pr("Opened successfully.\n")

-- SELF Header structure:
local magic = src:read(4)
pr(string.format("Magic: %02X %02X %02X %02X", magic:byte(1,4)))
if magic ~= "\83\67\69\0" then   -- "SCE\0"
    pr("Not a SELF file!")
    src:close(); log:close(); return
end

local version = read_u32(src)
pr("SELF Version: " .. version)
local header_size = read_u16(src)
pr("Header Size: " .. header_size)
local segment_count = read_u16(src)
pr("Number of Segments: " .. segment_count)
local key_revision = read_u16(src)
pr("Key Revision: " .. key_revision)
local flags = read_u16(src)
pr("Flags: 0x" .. string.format("%04X", flags))
local meta_offset = read_u32(src)
pr("Meta offset: 0x" .. string.format("%X", meta_offset))

local seg_base = 0x20
src:seek("set", seg_base)
pr("\n--- Segment Descriptors ---")
local elf_segment = nil
for i = 1, segment_count do
    local s_type = read_u32(src)
    local s_flags = read_u64(src)
    local s_offset = read_u64(src)
    local s_size = read_u64(src)
    local s_compressed = read_u32(src)
    local s_encrypted = read_u32(src)
    local s_pad = src:read(16)
    
    local type_name = "UNKNOWN"
    if s_type == 1 then type_name = "ELV (ELF)"
    elseif s_type == 2 then type_name = "PHDR (Program Headers)"
    elseif s_type == 3 then type_name = "SHDR (Section Headers)"
    elseif s_type == 4 then type_name = "META"
    elseif s_type == 5 then type_name = "CONTROL"
    elseif s_type == 6 then type_name = "SELF"
    end
    
    pr(string.format("Seg %02d: %-10s offset=0x%08X  size=0x%08X  compressed=%d  encrypted=%d  flags=0x%016X",
        i, type_name, s_offset, s_size, s_compressed, s_encrypted, s_flags))
    
    if s_type == 1 and s_size > 0 then
        elf_segment = {offset = s_offset, size = s_size, compressed = s_compressed, encrypted = s_encrypted}
    end
end

if not elf_segment then
    pr("\nNo ELF segment found in this SELF. It may be fully encrypted or a different format.")
    src:close(); log:close(); return
end

pr("\n--- Attempting ELF Extraction ---")
pr(string.format("Target segment: offset=0x%08X  size=0x%08X", elf_segment.offset, elf_segment.size))
if elf_segment.compressed ~= 0 then
    pr("WARNING: Segment is marked as COMPRESSED. Dumping raw, must decompress on PC.")
end
if elf_segment.encrypted ~= 0 then
    pr("WARNING: Segment is marked as ENCRYPTED. Dumping raw, need keys to decrypt.")
end

-- Extract the segment
src:seek("set", elf_segment.offset)
local dst = io.open(elf_path, "wb") or io.open(elf_path, "w")
if not dst then
    pr("ERROR: Cannot create output file " .. elf_path)
    src:close(); log:close(); return
end

local chunk_size = 1024 * 1024   -- 1 MB
local remaining = elf_segment.size
local total = 0
while remaining > 0 do
    local read_size = math.min(chunk_size, remaining)
    local data = src:read(read_size)
    if not data then break end
    dst:write(data)
    total = total + #data
    remaining = remaining - #data
    if total % (10*chunk_size) == 0 then
        pr(string.format("Extracted: %.2f MB", total / 1048576))
    end
end
dst:close()

pr("\nExtraction complete!")
pr(string.format("Bytes written: %d", total))
pr("Output: " .. elf_path)
pr("If the segment is not encrypted/compressed, this is a valid ELF.")
pr("Check first bytes: " .. string.format("%02X %02X %02X %02X", elf_segment.magic or 0,0,0,0))

local elf = io.open(elf_path, "rb") or io.open(elf_path, "r")
if elf then
    local magic2 = elf:read(4):byte(1,4)
    pr(string.format("Extracted file magic: %02X %02X %02X %02X", magic2 or 0,0,0,0))
    if magic2 == 0x7f and magic3 == 0x45 and magic4 == 0x4c and magic5 == 0x46 then   -- "\127ELF"
        pr("SUCCESS: Extracted file is a valid ELF!")
    end
    elf:close()
end

src:close()
log:close()
