<p align="center">
  <img width="220" src="https://raw.githubusercontent.com/MexrlDev/repo/refs/heads/main/PS3/LuaPlayer-PS3/Icon/IMG_0376.png">
</p>

<h1 align="center">LuaPlayer for PS3 v0.50 – Runtime Environment & Capability Report</h1>

<p align="center">
  Homebrew application analysis, API surface mapping, script deployment guide, and development reference for Lua scripting on PlayStation 3
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-PlayStation%203-blue">
  <img src="https://img.shields.io/badge/App%20Version-0.50-success">
  <img src="https://img.shields.io/badge/Lua%20Engine-Lua%205.2-orange">
  <img src="https://img.shields.io/badge/Requires-CFW%20%7C%20HFW-important">
  <img src="https://img.shields.io/badge/App%20Size-2311%20KB-red">
</p>

-----

# Executive Summary

This document consolidates the runtime environment, API surface, deployment mechanics, and development constraints of **LuaPlayer for PS3 v0.50** – a homebrew application that executes Lua scripts on a PlayStation 3 console running custom firmware (CFW) or Hybrid Firmware (HFW).

The application embeds a full **Lua 5.2** interpreter and extends it with libraries that abstract the PS3’s input, RSX graphics, audio, file system, system calls, and memory management. Scripts can be loaded from the internal hard disk or a USB mass storage device, with automatic error logging to the same media.

This report is intended for:

- Homebrew developers writing interactive Lua applications for PS3
- Documentation of the available API surface
- Planning script deployment workflows
- Understanding runtime limitations and security boundaries

> [!IMPORTANT]
> This report focuses on legal homebrew development. Exploit development, piracy, or firmware modification is not covered.

-----

# Download & Installation

|Attribute        |Detail                                                                                              |
|:----------------|:---------------------------------------------------------------------------------------------------|
|Application      |LuaPlayer for PS3                                                                                   |
|Version          |0.50                                                                                                |
|Download         |[store.brewology.com/ahomebrew.php?brewid=212](https://store.brewology.com/ahomebrew.php?brewid=212)|
|App Size         |2311 KB                                                                                             |
|Icon             |320 × 176 (shown above)                                                                             |
|Required Platform|CFW (4.xx) or HFW with homebrew support                                                             |

Install as a standard `.pkg` file via a package manager. After installation, script files must be placed manually using a file manager or USB.

-----

# Platform & Runtime Environment

|Field            |Value                                                         |
|:----------------|:-------------------------------------------------------------|
|Console          |PlayStation 3 (all models)                                    |
|Processor        |Cell Broadband Engine (1 PPE + 8 SPEs)                        |
|Main Memory      |256 MB XDR + 256 MB GDDR3 VRAM                                |
|Operating Context|GameOS (homebrew user‑space)                                  |
|Firmware         |CFW or HFW 4.xx                                               |
|Lua Runtime      |Lua 5.2 (custom built)                                        |
|Graphics API     |Custom PS3 RSX wrapper (`gfx`)                                |
|Audio API        |Custom PS3 audio wrapper (`snd`)                              |
|File Access      |`/dev_hdd0/game/LUAP00001/` (internal) or `/dev_usbXXX/` (USB)|

Full access to the RSX GPU, controllers, and storage is available, making the environment suitable for games, emulators, demos, and media tools.

-----

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

-----

# API Surface

Seven custom global tables extend the runtime with PS3 hardware capabilities.

-----

## Input – `pad`

Full support for up to 7 controllers (DualShock 3 / Sixaxis), including digital, analogue, pressure‑sensitive, and motion axes.

**Digital buttons** (return `true`/`false`):

```lua
pad.cross(), pad.circle(), pad.square(), pad.triangle(),
pad.up(), pad.down(), pad.left(), pad.right(),
pad.start(), pad.select(),
pad.L1(), pad.L2(), pad.R1(), pad.R2(), pad.L3(), pad.R3()
```

**Pressure‑sensitive buttons** (0–255, requires `pad.SetPressMode(1)`):

```lua
pad.crossPM(), pad.circlePM(), pad.squarePM(), pad.trianglePM(),
pad.upPM(), pad.downPM(), pad.leftPM(), pad.rightPM(),
pad.L1PM(), pad.L2PM(), pad.R1PM(), pad.R2PM()
```

**Analogue sticks** (signed 8‑bit):

```lua
pad.LanalogX(), pad.LanalogY(), pad.RanalogX(), pad.RanalogY()
```

**Sixaxis motion** (when enabled):

```lua
pad.Xaxis(), pad.Yaxis(), pad.Zaxis(), pad.Gaxis()
```

-----

## Graphics – `gfx`

Low‑level 2D and 3D rendering with vertex/pixel shader abstraction, blending, texturing, and font support.

**Core setup:**

```lua
gfx.Init()                          -- initialise graphics
gfx.Mode2D() / gfx.Mode3D()        -- switch between orthographic and perspective projection
gfx.Flip()                          -- present frame
gfx.Clear(color, zbuffer, stencil) -- clear buffers
gfx.ClearScreen()                   -- quick clear
gfx.End()                           -- end drawing
```

**2D primitives:**

```lua
gfx.DrawBG()                            -- draw background
gfx.DrawText(x, y, text)               -- draw text (requires font init)
gfx.BlitToScreen(surface, x, y)        -- copy surface to screen
gfx.SurfaceNew(width, height, format)  -- create off‑screen render target
gfx.SurfaceFree(surf)
gfx.SurfaceSetPixel(surf, x, y, color)
gfx.SurfaceClear(surf, color)
```

Texture formats: `TEX_FORMAT_L8`, `TEX_FORMAT_A1R5G5B5`, `TEX_FORMAT_R5G6B5`, `TEX_FORMAT_A4R4G4B4`, `TEX_FORMAT_A8R8G8B8`

**3D rendering:**

```lua
gfx.VertexPosition(x, y, z)
gfx.VertexPosition4(x, y, z, w)
gfx.VertexColor(r, g, b, a)
gfx.VertexTexture(u, v)
gfx.SetPolygon(mode)        -- set primitive type
gfx.LoadTexture(file)
gfx.SetTexture(tex)
gfx.SetTextureWrap(u, v)
```

Primitive types: `POINTS`, `LINES`, `LINE_STRIP`, `LINE_LOOP`, `TRIANGLES`, `TRIANGLE_STRIP`, `TRIANGLE_FAN`, `QUADS`, `QUAD_STRIP`, `POLYGON`

**Lighting:**

```lua
gfx.SetAmbientLight(color)
gfx.SetLight(index, ...)
gfx.SetLightsOff()
-- Constants: gfx.LIGHT_DISABLED, gfx.LIGHT_DIFFUSE, gfx.LIGHT_SPECULAR
```

**Materials:**

```lua
gfx.MaterialAmbient()
gfx.MaterialDiffuse()
gfx.MaterialSpecular()
gfx.MaterialEmissive()
```

**Matrices:**

```lua
gfx.MatrixNew()
gfx.MatrixFree()
gfx.MatrixSetModelView()
gfx.MatrixSetProjection()
gfx.MatrixMultiply()
gfx.MatrixTranslation()
gfx.MatrixRotationX() / gfx.MatrixRotationY() / gfx.MatrixRotationZ()
gfx.MatrixScale()
gfx.MatrixProjPerspective()
gfx.GetMatrixData()
```

**Fonts:**

```lua
gfx.InitFont()                          -- global init
gfx.FontAddBitmap() / gfx.FontAddTTF() -- load fonts
gfx.FontSelect(font)
gfx.FontSetSize(size)
gfx.FontSetColors(fg, bg)
gfx.FontSetAutoCenter(on)
gfx.FontSetAutoNewLine(on)
gfx.FontSetZ(z)
gfx.FontDrawString(x, y, text)
gfx.FontDrawChar(x, y, char)
gfx.FontGetX() / gfx.FontGetY()
```

**Blending & alpha:**

```lua
gfx.BlendFunction(rgbSrc, rgbDst, alphaSrc, alphaDst, rgbFunc, alphaFunc)
gfx.AlphaTest(func, value)
-- Constants: BLEND_FUNC_SRC_RGB_ONE, BLEND_FUNC_DST_ALPHA_ONE, BLEND_RGB_FUNC_ADD, etc.
```

**Video information:**

```lua
gfx.GetVideoResolution()      -- returns width, height
gfx.GetVideoAspect()          -- aspect ratio
gfx.GetVideoPitchSize()       -- pitch
gfx.GetCurrentVideoBufferID() -- current backbuffer
```

-----

## Audio – `snd`

Two‑channel audio system: background music (BGMusic) and voice channels.

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

-----

## File System – `fs`

POSIX‑like file API with direct access to PS3 device paths.

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

-----

## System – `sys`

Low‑level system and hypervisor calls. Use with care.

```lua
sys.Rand(max)                      -- random integer
sys.TimerSleep(s)                  -- blocking delay (seconds)
sys.TimerUsleep(us)                -- blocking delay (microseconds)
sys.ModuleLoad(path)
sys.ModuleUnload(id)
sys.ModuleIsLoaded(name)
sys.TimeGetTimebaseFreq()          -- timer frequency
sys.UtilRegisterCallback()
sys.UtilCheckCallback()
sys.UtilUnregisterCallback()       -- system event hooks

-- System menu constants
-- SYSUTIL_MENU_OPEN, SYSUTIL_MENU_CLOSE, SYSUTIL_DRAW_BEGIN, SYSUTIL_DRAW_END, SYSUTIL_EXIT_GAME
```

> [!WARNING]
> `sys.Lv1Peek`, `sys.Lv1Poke`, `sys.Lv2Peek`, and `sys.Lv2Poke` provide direct hypervisor/kernel memory access. Arbitrary use can brick or damage the console firmware. These functions exist for advanced system research only.

-----

## Memory – `mem`

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

-----

## Networking – `net`

Basic network debug logging (no socket API exposed).

```lua
net.Initialize() / net.Deinitialize()
net.initNetDebug()
net.dbg_printf(fmt, ...)
```

-----

## Image Surfaces – `surface`

Simple image loading and surface manipulation.

```lua
surface.new(width, height)    -- create surface
surface.LoadIMG(file)         -- load PNG/JPG into a surface
surface.DisplayFormat(surf)   -- format info
surface.setRectPos(surf, x, y)-- set position
surface.getRes(surf)          -- get width, height
```

-----

## Bitwise Operations – `bit32`

Standard Lua 5.2 `bit32` library:

```lua
bit32.band, bit32.bor, bit32.bxor, bit32.bnot,
bit32.lshift, bit32.rshift, bit32.arshift,
bit32.lrotate, bit32.rrotate,
bit32.extract, bit32.replace, bit32.btest
```

-----

## Global Helper Functions

```lua
StartGFX() / EndGFX() / InitGFX() / InitFont() / FlipGFX()
BlitToScreen(surface, x, y)  -- fast surface blit
DrawText(x, y, text)         -- quick text draw
ScreenRes()                  -- returns screen width and height
```

-----

# Script Deployment & Execution

LuaPlayer always loads a script named `app.lua`. The application searches for it in the following order:

**1. Internal HDD**

Path: `/dev_hdd0/game/LUAP00001/app.lua`

Place the script in the game’s data folder using a file manager (e.g., multiMAN).

**2. USB Mass Storage**

Root directory of any connected USB drive (`/dev_usb000/`, `/dev_usb001/`, …). The script must be named exactly `app.lua`.

**Error logging behaviour:**

If a script crashes at runtime, LuaPlayer automatically writes an error report:

- When the script is loaded from **USB**, the error log is saved to the same USB device (usually in the root or a `logs/` subdirectory, depending on the build).
- When the script is loaded from **internal HDD**, the error log is written locally inside `/dev_hdd0/game/LUAP00001/`.

**Headless execution:**

Scripts that require no graphical user interface (pure computation, file operations, etc.) will run, produce their output, and then exit normally. The application quits automatically after script termination unless the script enters an interactive loop.

-----

# Development Best Practices

- Target **Lua 5.2** – avoid syntax from Lua 5.3+.
- Keep main loops event‑driven using pad polling and `gfx.Flip()`.
- Limit memory usage – monitor allocations; use `mem.GetUserMemorySize()` to stay informed.
- Prefer `surface.LoadIMG` for images; use `gfx.LoadTexture` for 3D textures.
- Use `snd.BGMusic` for background music and voice channels for sound effects.
- Clean up resources: free surfaces, close files, stop voices before exit.
- Test on real hardware early; RSX behaviour may differ from emulators.
- Avoid frequent `sys.Lv1Peek`/`sys.Lv2Peek` unless absolutely necessary – they can crash the console.

-----

# Security & Stability Considerations

While LuaPlayer runs in user‑space, it exposes low‑level memory access that can compromise system stability or be misused. Homebrew developers should:

- Never ship scripts that randomly poke hypervisor/kernel addresses.
- Validate all file paths to avoid unintended access.
- Be cautious with `fs.Mount` / `fs.Umount` to prevent filesystem corruption.
- Understand that a script crash may leave RSX or audio resources unreleased; a system reboot may be required.

-----

# Suitable For

- 2D games and graphical demos
- 3D homebrew experiments (with shader‑free pipeline)
- Media players and image viewers
- File management utilities
- Educational programming on real console hardware
- Rapid prototyping of PS3 applications

# Not Suitable For

- Applications requiring modern GPU features (geometry shaders, compute)
- High‑performance network servers (no socket API)
- Multi‑threaded Lua workloads (no Lanes or true threading)
- Secure/encrypted applications (no SubtleCrypto)

-----

# Final Assessment

LuaPlayer for PS3 v0.50 is a mature and capable homebrew runtime that transforms the PlayStation 3 into a versatile Lua scripting platform. Its comprehensive API coverage – from controller input to 3D graphics – combined with simple USB/local deployment makes it ideal for hobbyist developers and educators.

The presence of raw hypervisor/kernel memory access demands responsible use, but the core libraries provide everything needed for rich interactive applications without resorting to low‑level hacks.

Long‑term support and development benefit from:

1. Strict adherence to Lua 5.2 semantics
1. Careful resource management
1. Defensive coding against invalid file paths and memory exhaustion
1. Regular testing on real CFW/HFW consoles

-----

# Conclusion

LuaPlayer for PS3 v0.50 offers a unique gateway to writing and running Lua on the PS3 with near‑native hardware access. Its well‑documented API surface, straightforward script deployment, and automatic error reporting lower the barrier for console homebrew development. As a reference for future projects or as a stable base for new creations, it stands as a reliable and powerful homebrew engine.
