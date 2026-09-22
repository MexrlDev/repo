-- MexrlDev - MIT
local out = {}
local function w(s) out[#out+1] = tostring(s) end
local function ts(v) local ok,s=pcall(tostring,v) return ok and s or "<err>" end
local function pad(n) return string.rep("  ", n) end
local function is_id(k) return type(k)=="string" and k:match("^[%a_][%w_]*$") end

local function dump(v, name, depth, seen, maxd)
  depth = depth or 0; maxd = maxd or 20; seen = seen or {}
  local pre, t = pad(depth), type(v)
  if t=="table" or t=="userdata" then
    if seen[v] then w(pre..name.." = <circular>") return end
    seen[v] = true
  end
  if t == "table" then
    w(pre..name.." = {")
    local mt = debug.getmetatable(v)
    if mt then dump(mt, "<metatable>", depth+1, seen, maxd) end
    if depth < maxd then
      local keys = {}
      for k in pairs(v) do keys[#keys+1] = k end
      table.sort(keys, function(a,b)
        local ta,tb=type(a),type(b)
        if ta~=tb then return ta<tb end
        if ta=="number" then return a<b end
        if ta=="string" then return a<b end
        return ts(a)<ts(b)
      end)
      for _,k in ipairs(keys) do
        dump(v[k], is_id(k) and k or ("["..ts(k).."]"), depth+1, seen, maxd)
      end
    end
    w(pre.."}")
  elseif t == "function" then
    local i = debug.getinfo(v, "nSuf") or {}
    w(pre..name.." = <"..(i.what or "?").." "..(i.short_src or "?")
      ..":"..(i.linedefined or -1).."-"..(i.lastlinedefined or -1)..">")
    if depth < maxd then
      local n = 1
      while true do
        local un, uv = debug.getupvalue(v, n)
        if not un then break end
        if un == "_ENV" and uv == _G then
          w(pad(depth+1).."_ENV = <_G>")
        else
          dump(uv, un=="" and ("up["..n.."]") or un, depth+1, seen, maxd)
        end
        n = n + 1
      end
    end
  elseif t == "userdata" then
    w(pre..name.." = <userdata "..ts(v)..">")
    local mt = debug.getmetatable(v)
    if mt then dump(mt, "<metatable>", depth+1, seen, maxd) end
    for i=1,16 do
      local ok, uv = pcall(debug.getuservalue, v, i)
      if not ok or uv==nil then break end
      dump(uv, "uservalue["..i.."]", depth+1, seen, maxd)
    end
  elseif t == "thread" then
    w(pre..name.." = <thread "..ts(v)..">")
    local lvl = 1
    while lvl <= 30 do
      local i = debug.getinfo(v, lvl, "nSl")
      if not i then break end
      w(pad(depth+1).."["..lvl.."] "..(i.what or "?").." "
        ..(i.short_src or "?")..":"..(i.currentline or -1)
        .."  "..(i.name or "(anon)"))
      lvl = lvl + 1
    end
  else
    w(pre..name.." = "..ts(v))
  end
end

local function sec(t) w(""); w("== "..t); w("") end

sec("_G")            for k,v in pairs(_G)             do dump(v, ts(k), 0, {}) end
sec("package.loaded") for k,v in pairs(package.loaded) do dump(v, ts(k), 0, {}) end
sec("package.preload")for k,v in pairs(package.preload)do dump(v, ts(k), 0, {}) end
sec("searchers")     for i,v in ipairs(package.searchers) do dump(v, "s["..i.."]", 0, {}) end
sec("registry")      dump(debug.getregistry(), "registry", 0, {})
sec("string_mt")     dump(debug.getmetatable(""), "string_mt", 0, {})
sec("file_mt")       dump(debug.getmetatable(io.stdout), "file_mt", 0, {})
sec("__lua_objc")    dump(_G.__lua_objc, "__lua_objc", 0, {})

print(table.concat(out, "\n"))
