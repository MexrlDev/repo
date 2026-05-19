-- PS3 Lua API Dumper by Max
-- PLEASE... namw it app.lua and put it into a usb..

-- ==
-- 1. detect a writable USB root
-- ==
local function find_writable_usb()
    local candidates = {"/dev_usb000", "/dev_usb001", "/dev_usb002", "/dev_usb003"}  -- cover all possibilities
    for _, root in ipairs(candidates) do
        local test_file = root .. "/.luatest_write"
        local f, err = io.open(test_file, "w")
        if f then
            f:close()
            os.remove(test_file)
            return root
        end
    end
    error("No writable USB device found. Tried: " .. table.concat(candidates, ", "))
end

local usb_root = find_writable_usb()
local out_path = usb_root .. "/lua_full_dump.txt"

-- ==
-- 2. Helper functions for logging and table dumping
-- ==
local function log(f, ...)
    local args = {...}
    for _, v in ipairs(args) do
        f:write(tostring(v))
    end
    f:write("\n")
end

local function dump_table(f, t, name, indent, depth, seen)
    indent = indent or 0
    depth = depth or 0
    seen = seen or {}
    local prefix = string.rep("  ", indent)

    if depth > 2 then
        log(f, prefix .. name .. " = { ... } (max depth)")
        return
    end
    if seen[t] then
        log(f, prefix .. name .. " = (circular)")
        return
    end
    seen[t] = true

    log(f, prefix .. name .. " = {")
    for k, v in pairs(t) do
        local key_str = type(k) == "string" and k or "[" .. tostring(k) .. "]"
        local vtype = type(v)
        if vtype == "function" then
            log(f, prefix .. "  " .. key_str .. " (function)")
        elseif vtype == "table" then
            dump_table(f, v, key_str, indent + 2, depth + 1, seen)
        elseif vtype == "userdata" then
            log(f, prefix .. "  " .. key_str .. " (userdata)")
        else
            log(f, prefix .. "  " .. key_str .. " = " .. tostring(v))
        end
    end
    log(f, prefix .. "}")
end

-- ==
-- 3. Open the output file
-- ==
local file, err = io.open(out_path, "w")
if not file then
    error("Cannot create log file at " .. out_path .. ": " .. tostring(err))
end

-- ==
-- 4. Start dumping everything
-- ==
log(file, "=== PS3 Lua Full API Dump ===")
log(file, "Date: " .. os.date())
log(file, "USB root used: " .. usb_root)
log(file, "_VERSION: " .. tostring(_VERSION))
log(file, "")
log(file, "[1] Global environment (tables & functions)")
local known_modules = {
    "pad", "gfx", "sys", "fs", "net", "surface", "snd",
    "mem", "bit32", "StartGFX", "EndGFX", "InitGFX", "InitFont",
    "FlipGFX", "BlitToScreen", "DrawText", "ScreenRes", "rawlen"
}
for _, modname in ipairs(known_modules) do
    local val = _G[modname]
    if val ~= nil then
        log(file, "--- " .. modname .. " (" .. type(val) .. ") ---")
        if type(val) == "table" then
            dump_table(file, val, modname, 0)
        elseif type(val) == "function" then
            log(file, "  (global function)")
        else
            log(file, "  value: " .. tostring(val))
        end
        log(file, "")
    end
end

log(file, "[2] Other global tables (not in the list above)")
for k, v in pairs(_G) do
    if type(k) == "string" and type(v) == "table" then
        local already = false
        for _, m in ipairs(known_modules) do
            if k == m then already = true; break end
        end
        if not already and k ~= "_G" and k ~= "package" and k ~= "debug" and k ~= "coroutine" then
            log(file, "--- " .. k .. " (table) ---")
            dump_table(file, v, k, 0)
            log(file, "")
        end
    end
end

log(file, "[3] Filesystem listing (using 'fs' module)")
if fs then
    local dir_func = fs.dir or fs.listdir or fs.readdir or fs.list
    if dir_func and type(dir_func) == "function" then
        local paths = {"/dev_usb000", "/dev_usb001", "/app_home", "/dev_flash", "/dev_hdd0"}
        for _, p in ipairs(paths) do
            log(file, "  Trying fs.dir(\"" .. p .. "\")")
            local ok, list = pcall(dir_func, p)
            if ok and list then
                local count = 0
                for name in list do
                    if count < 20 then
                        log(file, "    " .. name)
                    end
                    count = count + 1
                end
                if count > 20 then log(file, "    ... (" .. count .. " entries)") end
            else
                log(file, "    failed: " .. tostring(list))
            end
        end
    else
        log(file, "  'fs' table has no dir/list function. Keys in fs:")
        for k, v in pairs(fs) do
            if type(k) == "string" then
                log(file, "    " .. k .. " (" .. type(v) .. ")")
            end
        end
    end
else
    log(file, "  'fs' module not present.")
end

log(file, "")
log(file, "[4] Direct file read test (using io.open)")
local test_files = {
    "/dev_flash/etc/version.txt",
    "/dev_flash/vsh/etc/version.txt"
}
for _, fpath in ipairs(test_files) do
    local rf, rerr = io.open(fpath, "r")
    if rf then
        local content = rf:read("*a")
        rf:close()
        log(file, "  " .. fpath .. " readable: " .. content:match("[^\r\n]+"))
    else
        log(file, "  " .. fpath .. " not accessible: " .. tostring(rerr))
    end
end

log(file, "")
log(file, "[5] Memory")
log(file, "  Lua memory (KB): " .. collectgarbage("count"))

log(file, "")
log(file, "=== End of Full Dump ===")
file:close()
