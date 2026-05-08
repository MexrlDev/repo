<p align="center">
  <img width="220" src="https://upload.wikimedia.org/wikipedia/commons/8/80/DVB_Logo.svg">
</p>

<h1 align="center">GX6605S DVB Receiver Architecture & Embedded System Analysis</h1>

<p align="center">
  Technical breakdown of GX6605S-based satellite receivers, firmware structure, DVB pipeline architecture, multimedia subsystems, and embedded Linux runtime behaviour.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/SoC-GX6605S-blue">
  <img src="https://img.shields.io/badge/Platform-Embedded%20Linux-success">
  <img src="https://img.shields.io/badge/System-DVB--S2-orange">
  <img src="https://img.shields.io/badge/Architecture-ARM%20%2F%20MIPS-red">
  <img src="https://img.shields.io/badge/Firmware-Legacy-important">
</p>

---

# Platform Architecture

The receiver is a compact embedded Linux DVB appliance built around the GX6605S multimedia SoC.

Its hardware stack combines RF processing, hardware video decoding, networking, storage, and display output into a highly constrained low-power environment.

---

## Core Hardware Stack

| Component | Purpose |
|:--|:--|
| GX6605S SoC | Main CPU + multimedia decoder |
| DVB-S2 Tuner | Receives satellite RF signals |
| Demodulator | Converts DVB transport streams |
| SPI NOR Flash | Stores bootloader and firmware |
| DDR RAM | Runtime system memory |
| HDMI Encoder | Digital audio/video output |
| USB Controller | External storage and Wi-Fi |
| Ethernet / Wi-Fi Stack | IPTV and networking |

---

## Integrated GX6605S Features

The GX6605S integrates several dedicated multimedia and broadcast processing blocks directly into the SoC:

- MPEG2 decoder
- H.264 decoder
- Transport stream processor
- Audio DSP
- Framebuffer engine
- Hardware scaler
- DVB demultiplexer
- CAS hooks
- USB host controller
- Ethernet MAC

This level of hardware integration allows inexpensive receivers to simultaneously perform:

- Live TV decoding
- IPTV playback
- USB recording
- Subtitle rendering
- EPG processing
- Network communication
- Softcam connectivity

within very limited hardware constraints.

---

# Boot Process

The complete boot chain is relatively typical for embedded Linux DVB systems.

```text
Power On
   ↓
Boot ROM (inside GX6605S)
   ↓
SPI NOR Flash
   ↓
Bootloader (V3.38)
   ↓
Kernel Decompression
   ↓
Root Filesystem Mount
   ↓
Hardware Initialization
   ↓
Tuner Initialization
   ↓
Network Services
   ↓
GUI Middleware
   ↓
Live TV
```

---

## Bootloader Importance

The bootloader is one of the most critical system components.

Observed loader version:

```text
V3.38(2 28 0 7)
```

The loader is responsible for:

- Firmware validation
- DDR initialization
- Display initialization
- USB recovery mode
- Kernel loading

> [!WARNING]
> Incompatible firmware images may permanently brick the receiver if the bootloader rejects or improperly initializes hardware.

---

# Flash Memory Layout

Typical GX6605S flash layouts follow a fixed partition structure.

| Address | Region |
|:--|:--|
| `0x000000` | Bootloader |
| `0x040000` | Environment |
| `0x080000` | Kernel |
| `0x200000` | RootFS |
| `0x700000` | Resources |
| `0x780000` | UserDB |

---

## User Database Contents

The UserDB partition typically stores:

- Channels
- Satellites
- Transponders
- Favorites
- IPTV lists
- Passwords
- Softcam configuration

This explains indicators commonly displayed in firmware menus such as:

- "Channel Used"
- "Satellite Used"
- "IP Used"

---

# Satellite Engine

The DVB subsystem forms the core functionality of the receiver.

The signal processing chain is:

```text
LNB
 ↓
Tuner
 ↓
Demodulator
 ↓
Transport Stream Parser
 ↓
Video / Audio Decoder
```

---

## Supported Standards

The receiver commonly supports:

- DVB-S
- DVB-S2
- MPEG2
- MPEG4
- H.264

The tuner receives RF signals from:

- Ku-band
- C-band

through:

- LNB voltage switching
- 22KHz tone control
- DiSEqC signalling

---

# LNB Control System

The firmware directly manipulates electrical signals delivered through the coaxial cable.

---

## LNB Voltage Control

| Voltage | Polarization |
|:--|:--|
| 13V | Vertical |
| 18V | Horizontal |

---

## 22KHz Tone Control

The 22KHz tone controls universal LNB band switching.

| State | Behaviour |
|:--|:--|
| OFF | Low band |
| ON | High band |
| AUTO | Firmware-controlled |

---

# DiSEqC System

DiSEqC is a serial communication protocol transmitted over the coaxial line.

Supported versions commonly include:

| Version | Function |
|:--|:--|
| 1.0 | 4-port switch |
| 1.1 | 16-port switch |
| 1.2 | Motor movement |
| 1.3 (USALS) | Automatic motor positioning |

The receiver sends pulse-coded commands directly over the LNB signal line.

---

# USALS Motor Control

USALS is one of the more sophisticated firmware subsystems.

The user provides:

- Latitude
- Longitude

The firmware then calculates the required motor angle using orbital geometry.

```math
\theta = \arctan\left(\frac{\sin(\Delta L)}{\tan(\phi)}\right)
```

Where:

- θ = dish motor angle
- ΔL = satellite longitude difference
- φ = observer latitude

This enables automatic dish positioning toward orbital targets.

---

# Blind Scan Engine

Blind scan functionality performs real RF spectrum analysis rather than simply checking predefined transponders.

Typical sweep range:

```text
950 MHz → 2150 MHz
```

The tuner attempts to identify:

- Symbol rates
- Carrier lock
- Modulation type
- FEC parameters

This process is computationally expensive for low-power embedded hardware.

---

# Channel Database System

Channels are internally stored as structured records.

Typical firmware structures resemble:

```c
struct channel {
    uint16_t service_id;
    uint16_t pmt_pid;
    uint16_t video_pid;
    uint16_t audio_pid;
    uint16_t pcr_pid;
    uint8_t  scrambled;
    char name[64];
};
```

The firmware builds these structures from DVB SI tables including:

- PAT
- PMT
- SDT
- NIT
- EIT

---

# EPG System

The Electronic Program Guide subsystem continuously parses DVB Event Information Tables.

7-day EPG functionality requires:

- Continuous EIT parsing
- Event caching
- RAM database updates
- GUI synchronization

This explains why guide data may populate slowly on some channels.

---

# Audio System

Supported audio formats commonly include:

- MPEG audio
- AAC
- AC3 / Dolby

---

## AC3 Bypass

"AC3 Bypass" typically means:

- The compressed Dolby stream is passed directly through HDMI/SPDIF
- The receiver does not decode audio internally

---

# Video Pipeline

The SoC contains dedicated hardware video decode blocks.

Typical rendering pipeline:

```text
TS Stream
 ↓
Demultiplexer
 ↓
H.264 Decoder
 ↓
Framebuffer
 ↓
Scaler
 ↓
HDMI Encoder
```

Hardware acceleration allows smooth HD playback despite limited CPU resources.

---

# USB / PVR System

Recording functionality usually works by saving raw MPEG transport streams directly to storage.

Typical output format:

```text
.ts
```

The receiver does not re-encode video.

Advantages include:

- Very low CPU usage
- Exact broadcast quality preservation

---

# Timeshift System

Timeshift functionality operates as a circular recording buffer.

```text
Live Stream
      ↓
USB Buffer
      ↓
Delayed Playback
```

Playback reads from a delayed position inside the rolling buffer.

---

# Media Player

The integrated media player often supports:

- AVI
- FLV
- MOV
- TS
- MP4

This suggests the firmware uses:

- FFmpeg-derived decoding libraries
- Hardware codec wrappers
- Proprietary multimedia middleware

---

# Network Stack

Supported networking methods typically include:

- Ethernet
- USB Wi-Fi
- 3G dongles

Observed Wi-Fi chipsets commonly include:

- MT7601
- RT5370

This implies the presence of:

- Linux USB driver stacks
- Ralink drivers
- WPA supplicant
- DHCP clients
- TCP/IP networking layers

---

# IPTV System

Indicators such as:

```text
IP Used 78/100
```

strongly suggest IPTV database support.

Typical IPTV features include:

- HTTP streaming
- M3U parsing
- HLS playback
- TS playback
- Multicast support

---

# Softcam / Card Sharing

Many GX6605S receivers implement:

- CCCAM
- NEWCAMD
- MGCamd
- Twin protocol

Typical processing flow:

```text
Encrypted Channel
        ↓
ECM Extraction
        ↓
Network Softcam Server
        ↓
CW Return
        ↓
CSA Descrambling
```

Some SoCs include hardware CSA acceleration.

---

# Security Model

Security on these systems is generally weak compared to modern embedded platforms.

Common issues include:

- Unsigned firmware
- Hidden telnet services
- Hardcoded credentials
- Buffer overflows
- Unsafe parsers
- Exposed UART debugging
- No ASLR
- Outdated Linux kernels

Because of this, many GX6605S receivers can be:

- Rooted
- Dumped
- Modified
- Crossflashed
- Reverse engineered

---

# UART Debugging

Most boards expose UART pads containing:

```text
GND
RX
TX
3.3V
```

Typical configuration:

```text
115200 baud
```

Boot logs frequently reveal:

- Kernel version
- Filesystem details
- Memory maps
- Mount points
- Debug services

In some cases UART access exposes:

- Shell access
- Bootloader consoles
- Firmware recovery interfaces

---

# Firmware Structure

Firmware packages commonly contain:

- Header
- Kernel
- RootFS
- Resources
- Fonts
- Language packs
- Databases
- Boot logos

Compression methods frequently include:

- LZMA
- SquashFS
- CramFS

---

## Common Extraction Tools

```bash
binwalk
unsquashfs
dd
hexdump
```

---

# Why These Receivers Are Heavily Cloned

The OEM ecosystem usually works as:

```text
Reference PCB
        +
Reference Firmware
        +
Brand Logo Replacement
        =
New Receiver Brand
```

Many "different" receivers are effectively:

- The same PCB
- The same SoC
- The same firmware base

with only cosmetic branding differences.

---

# Hidden Menus

Common engineering access codes include:

```text
6666
7777
8888
9999
```

These menus may expose:

- CAS settings
- Network protocols
- Patch menus
- Key editors
- Server configuration
- Firmware tools

---

# Real Capabilities of the Device

Despite their low cost, these receivers effectively function as:

- Embedded Linux computers
- RF analyzers
- DVB demultiplexers
- MPEG decoding systems
- Network streaming clients
- Embedded databases
- Motorized satellite controllers
- USB media centers

all within an extremely constrained environment typically limited to:

- ~64MB RAM
- Small flash storage
- Low-power embedded CPUs
