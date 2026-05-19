<p align="center">
  <img width="220" src="https://raw.githubusercontent.com/MexrlDev/repo/refs/heads/main/PS3/LuaPlayer-PS3/Icon/IMG_0376.png">
</p>

<h1 align="center">LuaPlayer for PS3 v0.50</h1>

<p align="center">
  Homebrew application analysis, API surface mapping, script deployment guide, and development reference for Lua scripting on PlayStation 3
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-PlayStation%203-blue">
  <img src="https://img.shields.io/badge/App%20Version-0.50-success">
  <img src="https://img.shields.io/badge/Lua%20Engine-Lua%205.2-orange">
  <img src="https://img.shields.io/badge/Requires-CFW%20%7C%20HFW-important">
  <img src="https://img.shields.io/badge/App%20Size-2311%20KB-red">
  <img src="https://img.shields.io/badge/Firmware%20Tested-4.92-lightgrey">
</p>

---

# Executive Summary

This document consolidates the **actual** runtime environment, API surface, deployment mechanics, and development constraints of **LuaPlayer for PS3 v0.50** – a homebrew application that executes Lua scripts on a PlayStation 3 console running custom firmware (CFW) or Hybrid Firmware (HFW). All findings are based on real‑hardware testing with firmware **4.92**.

The application embeds a full **Lua 5.2** interpreter and extends it with libraries that abstract the PS3’s input, RSX graphics, audio, file system, system calls, and memory management. Scripts can be loaded from the internal hard disk or a USB mass storage device, with automatic error logging to the same media.

> **Something Sad** – On the tested firmware, the graphics framebuffer is **never displayed**. The XMB retains screen ownership, meaning all `FlipGFX()` calls and drawing are purely internal. Visual output is **not** visible on the TV. All feedback must come from USB logs, audio cues, or file output. This report describes the environment as it actually behaves, not as originally documented.

---

# Download & Installation

| Attribute         | Detail                                                                                              |
| :---------------- | :-------------------------------------------------------------------------------------------------- |
| Application       | LuaPlayer for PS3                                                                                   |
| Version           | 0.50                                                                                                |
| Download          | [store.brewology.com/ahomebrew.php?brewid=212](https://store.brewology.com/ahomebrew.php?brewid=212) |
| App Size          | 2311 KB                                                                                             |
| Required Platform | CFW (4.xx) or HFW with homebrew support                                                             |

Install as a standard `.pkg` file via a package manager. After installation, script files must be placed manually using a file manager or USB.

---

# Platform & Runtime Environment

| Field             | Value                                                     |
| :---------------- | :-------------------------------------------------------- |
| Console           | PlayStation 3 (all models)                                |
| Processor         | Cell Broadband Engine (1 PPE + 8 SPEs)                    |
| Main Memory       | 256 MB XDR + 256 MB GDDR3 VRAM                            |
| Operating Context | GameOS (homebrew user‑space)                              |
| Firmware Tested   | CFW 4.92 (behaviour may differ on earlier versions)       |
| Lua Runtime       | Lua 5.2 (custom built)                                    |
| Graphics API      | Custom PS3 RSX wrapper (`gfx`) – **framebuffer invisible** |
| Audio API         | Custom PS3 audio wrapper (`snd`)                           |
| File Access       | `/dev_hdd0/game/LUAP00001/` (internal) or `/dev_usbXXX/` (USB) |

---

# Lua Runtime Core

All standard Lua 5.2 libraries are present:

```lua
math, string, table, os, io, debug, coroutine, bit32
```

Global functions include:

```lua
rawlen, dofile, loadfile, pcall, xpcall, require, print, type, next, pairs, ipairs, ...
```

The Lua state consumes approximately 125 KB at startup, leaving the majority of system memory free for user scripts and assets.

---

API Surface – Actual Behaviour

Seven custom global tables extend the runtime. This section reflects what actually works on firmware 4.92, with broken or non‑functional calls clearly flagged.

---

Input – pad

Full support for up to 7 controllers (DualShock 3 / Sixaxis). All input reads must follow a single pad.InitPads(n) call.

```lua
pad.InitPads(1)            -- ALWAYS call with number of controllers before reading
sys.TimerUsleep(500000)    -- mandatory settle time after init
```

Digital buttons – return 0 / 1 (not booleans!):

```lua
pad.cross(0), pad.circle(0), pad.square(0), pad.triangle(0),
pad.up(0), pad.down(0), pad.left(0), pad.right(0),
pad.start(0), pad.select(0),
pad.L1(0), pad.L2(0), pad.R1(0), pad.R2(0), pad.L3(0), pad.R3(0)
```

Pressure‑sensitive buttons and analogue sticks exist but have not been exhaustively tested; expect the same call patterns as documented elsewhere.

Important: Immediately after InitPads, start(0) may briefly return 1. Always debounce with a hold counter (see Common Pitfalls).

---

Graphics – gfx

All drawing functions succeed internally, but the resulting image is never displayed on the TV. Use this module only for offline rendering or if you later run under a loader that owns the screen.

Core setup:

```lua
gfx.Init(mode, param)   -- requires TWO numbers, e.g. gfx.Init(720, 0) or gfx.Init(1080, 0)
gfx.Mode2D()            -- switch to 2D projection
gfx.Flip() / FlipGFX()  -- present frame (invisible on 4.92)
gfx.Clear(gfx.CLEAR_COLOR, color)  -- clear to solid colour
gfx.End()               -- end drawing
```

Warning: gfx.Init must be called exactly once and with two integer arguments. A second call causes a tiny3d_Init() failure and crash.

Primitives – only POINTS works:

```lua
gfx.SetPolygon(gfx.POINTS)   -- any other type returns ret(-3)
gfx.VertexPosition(x, y, z)  -- z must be 0 in 2D
gfx.VertexColor(r, g, b, a)  -- RGBA colour for vertices
```

All other primitive types (QUADS, TRIANGLES, etc.) are broken and will error.

Fonts – partially working:

```lua
gfx.FontSelect(0)                        -- built‑in font (slot 0)
gfx.FontSetColors(fg, bg)                -- set foreground/background colours
gfx.FontDrawString(x, y, text)           -- draw text (invisible)
gfx.FontSetSize(size)                    -- RETURNS FALSE, does nothing
-- Use the default size; text is still readable in logs if you capture framebuffer?
```

The global InitFont() helper crashes if called without a path – do not use it.

Blending & alpha:

```lua
gfx.BlendFunction(src, dst, alphaFunc)   -- three numbers, not six
-- e.g. gfx.BlendFunction(gfx.BLEND_FUNC_SRC_ALPHA_ONE, gfx.BLEND_FUNC_DST_ALPHA_ZERO, gfx.BLEND_ALPHA_FUNC_ADD)
```

Other gfx functions not yet exhaustively tested (texture loading, matrices, etc.). Assume they work but are invisible.

Global helper functions that are BROKEN or freeze the PS3:

· ScreenRes() → freezes PS3 instantly
· InitGFX(), StartGFX() → crash or no effect
· BlitToScreen(), DrawText() → no effect

Never call these.

---

Audio – snd

Two‑channel audio system works with WAV files.

```lua
snd.Init() / snd.Finalize()

-- BGMusic
snd.PlayBGMusic(file)
snd.StopBGMusic() / snd.PauseBGMusic()
snd.SetVolumeBGMusic(vol)
snd.GetTimeBGMusic() / snd.GetTotalTimeBGMusic()
snd.SetTimeBGMusic(time)
snd.StatusBGMusic() / snd.FreeBGMusic()

-- Voice channels (indexed 0‑N)
snd.SetVoice(index, file)
snd.PlayVoice(index) / snd.PauseVoice(index) / snd.StopVoice(index)
snd.FreeVoice(index)
snd.ChangeVolumeVoice(index, vol)
snd.ChangeFreqVoice(index, freq)

-- Global pause
snd.Pause()
```

All functions confirmed working with a standard beep.wav.

---

File System – fs

POSIX‑like file API with direct access to PS3 device paths. Fully functional.

```lua
-- File I/O
fs.Open(path, flags, mode)
fs.Close(fd)
fs.Read(fd, count)
fs.Write(fd, data)
fs.Lseek(fd, offset, whence)

-- Flags: RDONLY, WRONLY, RDWR, CREAT, EXCL, TRUNC, APPEND, MSELF
-- Whence: SEEK_SET, SEEK_CUR, SEEK_END

-- Directories
fs.Opendir(dir) / fs.Readdir(handle) / fs.Closedir(handle)

-- File operations
fs.Mkdir(path) / fs.Rmdir(path)
fs.Rename(old, new)
fs.Unlink(file)
fs.CopyFile(src, dst)
fs.Chmode(path, mode)

-- Info
fs.Stat(path) / fs.Fstat(fd)
fs.GetFreeSize(path)

-- Mount
fs.Mount(dev, dir, fstype, flags)
fs.Umount(dir)
```

Also, standard Lua io library works for binary files. Always use unbuffered writes and flush when logging to USB.

---

System – sys

Low‑level system and hypervisor calls.

```lua
sys.Rand(max)                      -- random integer
sys.TimerSleep(s)                  -- blocking delay (seconds)
sys.TimerUsleep(us)                -- blocking delay (microseconds)
sys.ModuleLoad(path)               -- present, untested
sys.ModuleUnload(id)
sys.ModuleIsLoaded(name)
sys.TimeGetTimebaseFreq()          -- timer frequency
sys.GetName()                      -- returns something, usable
sys.UtilRegisterCallback()         -- system event hooks
sys.UtilCheckCallback()
sys.UtilUnregisterCallback()

-- Memory peeking (dangerous)
sys.Lv2Peek(address)               -- reads 64‑bit aligned address
```

[!WARNING]
sys.Lv1Peek, sys.Lv1Poke, sys.Lv2Peek, sys.Lv2Poke provide direct hypervisor/kernel memory access. Arbitrary use can brick or damage the console firmware. Only Lv2Peek is confirmed working on aligned addresses.

---

Memory – mem

Custom memory containers.

```lua
mem.Allocate(size) / mem.Free(ptr)
mem.ContainerCreate(size)
mem.ContainerDestroy(id)
mem.ContainerGetSize(id)
mem.AllocateFromContainer(id, size)
mem.GetUserMemorySize()            -- total available memory

-- Page size constants
-- PAGE_SIZE_64K (512), PAGE_SIZE_1M (1024)
```

---

Networking – net

Basic network debug logging (no socket API exposed).

```lua
net.Initialize() / net.Deinitialize()
net.initNetDebug()
net.dbg_printf(fmt, ...)
```

Both Initialize and Deinitialize succeed; the module can be used to send debug messages over the network if properly configured.

---

Image Surfaces – surface

Simple image loading and surface manipulation. Blitting to screen is irrelevant because the framebuffer is invisible.

```lua
surface.new(width, height)    -- create surface
surface.LoadIMG(file)         -- load PNG/JPG into a surface
surface.DisplayFormat(surf)   -- format info
surface.setRectPos(surf, x, y)-- set position
surface.getRes(surf)          -- get width, height
```

---

Bitwise Operations – bit32

Standard Lua 5.2 bit32 library – fully available.

---

Global Helper Functions (summary)

Function Status
StartGFX() Broken – crash or no effect
EndGFX() Works (cleanup)
InitGFX() Broken – do not call
InitFont() Broken – requires path, crashes without it
FlipGFX() Works internally, but output invisible
BlitToScreen() No effect
DrawText() No effect
ScreenRes() Freezes PS3 instantly – never call

---

Script Deployment & Execution

LuaPlayer always loads a script named app.lua. The application searches for it in this order:

1. Internal HDD – /dev_hdd0/game/LUAP00001/app.lua
2. USB mass storage – root directory of any connected USB drive (/dev_usb000/, /dev_usb001/, …). The script must be named exactly app.lua.

Error logging:

If your script crashes at runtime, LuaPlayer automatically writes lua_error_log.txt to the same location where app.lua was loaded from (USB root or /dev_hdd0/game/LUAP00001/). This is the primary debugging tool, especially because the screen is blank.

Headless execution:

Scripts that require no graphical user interface (pure computation, file operations, etc.) will run, produce their output, and then exit normally. The application quits automatically after script termination unless the script contains an infinite loop with FlipGFX() (though the display remains black). For any interactive tool, use the pad‑driven infinite loop template below.

---

Common Pitfalls & How to Avoid Them

Pitfall 1 – Calling pad.start(0) too soon

After pad.InitPads(1), start may briefly read 1.
Fix: Add a 0.5‑second settle time and a hold‑to‑exit counter.

```lua
pad.InitPads(1)
sys.TimerUsleep(500000)

local start_held = 0
while true do
    if pad.start(0) then start_held = start_held + 1 else start_held = 0 end
    if start_held >= 10 then break end
    -- ...
end
```

Pitfall 2 – Using ScreenRes, InitGFX, StartGFX, or InitFont

Any of these can freeze the PS3 or cause a crash.
Fix: Never call them. Graphics initialisation must be:

```lua
gfx.Init(720, 0)   -- or (1080, 0) for 1080p
gfx.Mode2D()
gfx.SetPolygon(gfx.POINTS)
```

Pitfall 3 – Wrong argument count for gfx/pad functions

· gfx.Init needs two numbers.
· gfx.VertexPosition needs three numbers (x, y, z) – use z=0.
· gfx.BlendFunction needs three numbers (src, dst, combine).
· pad.InitPads needs one number (controller count).

Always check the error log; the message tells you exactly which argument is missing.

Pitfall 4 – Expecting screen output

The framebuffer is not visible on firmware 4.92. All feedback must be logged to USB (or played as sound). Design your scripts as headless tools.

Pitfall 5 – Logging without flushing

If your script crashes, the log file might be empty.
Fix: Use unbuffered I/O.

```lua
local logf = io.open("/dev_usb001/output.txt", "w")
logf:setvbuf("no")
local function log(msg)
    logf:write(msg .. "\n")
    logf:flush()
end
```

Pitfall 6 – Drawing too many points

Even though the screen is invisible, excessive gfx.VertexPosition calls can hang the GPU. Limit point draws and use gfx.Clear for backgrounds.

Pitfall 7 – Calling gfx.SetPolygon with anything but POINTS

Any other polygon type returns ret(-3) and fails. Stick to:

```lua
gfx.SetPolygon(gfx.POINTS)
```

---

Safe Script Skeleton (Headless, USB‑logged)

Use this as a starting point for any interactive (pad‑driven) script. It includes pad debouncing, optional audio beeps, and persistent USB logging.

```lua
-- Headless safe template for LUAPlayer v0.50 on PS3 4.92
local usb = "/dev_usb001"   -- adjust to your USB path
local logf = io.open(usb .. "/output.txt", "w")
logf:setvbuf("no")
local function log(msg)
    logf:write(msg .. "\n")
    logf:flush()
end

-- Graphics init (invisible, but required for gfx functions)
gfx.Init(720, 0)
gfx.Mode2D()
gfx.SetPolygon(gfx.POINTS)
gfx.FontSelect(0)
gfx.FontSetColors(0xFFFF00FF, 0x00000000)

-- Pad init with settle
pad.InitPads(1)
sys.TimerUsleep(500000)

-- Optional beep
if fs.Stat(usb .. "/beep.wav") then
    snd.Init()
    snd.SetVoice(0, usb .. "/beep.wav")
    local function beep() snd.PlayVoice(0) end
end

log("Script started. Press and hold START to exit.")

local start_held = 0
while true do
    if pad.start(0) then
        start_held = start_held + 1
    else
        start_held = 0
    end
    if start_held >= 10 then break end

    -- Your logic here
    -- ...

    sys.TimerUsleep(33000)   -- ~30 fps cap
end

log("Done.")
logf:close()
EndGFX()
```

---

What This Environment CAN Do (Practical Applications)

· File Manager: Browse, copy, delete, rename files on /dev_hdd0, /dev_flash, USB.
· ELF Extractor: Scan EBOOT.BIN files for the \127ELF magic and dump raw ELFs.
· Memory Dumper: Read any LV2‑accessible address with sys.Lv2Peek and save hex dumps.
· System Info Harvester: Firmware version, free space, memory stats.
· Network Debugger: net.Initialize works; you can send UDP debug messages.
· Automated Batch Processor: Read commands.txt from USB, execute tasks, write results back – fully autonomous.

---

What It CANNOT Do

· Display a UI (without a different homebrew loader that owns the screen).
· Use 3D graphics (only POINTS primitive works, and framebuffer is invisible).
· Decrypt or decompress SELF segments (no crypto available).
· Load external .so modules – dynamic library loading untested and likely unsupported.

---

Development Best Practices (Updated)

· Always write logs to USB; they are your only visual feedback.
· Keep pad reads event‑driven, with debounce on start.
· Limit memory usage – use mem.GetUserMemorySize() to stay informed.
· Clean up resources: close files, stop voices before exit.
· Test on real hardware; emulators may not replicate the 4.92 display issue.
· Avoid ScreenRes, InitGFX, StartGFX completely.
· For any future loader that grants display rights, the gfx font and drawing calls remain correct – only the framebuffer visibility changes.

---

Security & Stability Considerations

While LuaPlayer runs in user‑space, it exposes low‑level memory access. Homebrew developers should:

· Never ship scripts that randomly poke hypervisor/kernel addresses.
· Validate all file paths to avoid unintended access.
· Be cautious with fs.Mount / fs.Umount to prevent filesystem corruption.
· Understand that a script crash may leave RSX or audio resources unreleased; a system reboot may be required.

---

Use this fir API's

· [Api Debug Log](https://github.com/MexrlDev/repo/blob/main/PS3/LuaPlayer-PS3/Development/Dumped-Lua.txt)
