#!/usr/bin/env python3
# Remote Lua Loader Payload Sender – mobile friendly
# Works on Pythonica, PyCode..

import os
import sys
import socket
import struct
import select
import argparse

# ── CONFIG ─────────────────────────────
TARGET_IP     = ""   # default IP
PORT          = 9026            # default port
PAYLOAD_DIR   = "payloads"      # folder for .lua payloads
DEFAULT_FILE  = "payload.lua"   # fallback payload name
IP_FILE       = "target_ip.txt" # optional file with IP[:PORT]
TIMEOUT       = 6               # connection timeout
# ───────────────────────────────────────

# Signal codes (for crash reports)
SIGNALS = {
    4: "SIGILL",
    10: "SIGBUS",
    11: "SIGSEGV",
}
COMMAND_MAGIC = struct.pack('<Q', 0xFFFFFFFF)
MAGIC_VALUE = struct.pack('<Q', 0x13371337)
MAGIC_LEN = len(MAGIC_VALUE)
SIGNAL_LEN = 16
MCONTEXT_LEN = 0x100
DISABLE_SIGNAL_HANDLER = 0
ENABLE_SIGNAL_HANDLER = 1

G = '\033[92m'
R = '\033[91m'
Y = '\033[93m'
C = '\033[96m'
W = '\033[0m'

def banner():
    print(C + "=" * 52)
    print("  Remote Lua Loader Payload Sender")
    print("=" * 52 + W)

def ensure_payload_dir():
    if not os.path.isdir(PAYLOAD_DIR):
        os.makedirs(PAYLOAD_DIR)
        print(f"{G}[+]{W} Created '{PAYLOAD_DIR}/' - place .lua payloads here.")

def read_target_file():
    if not os.path.isfile(IP_FILE):
        with open(IP_FILE, "w") as f:
            f.write("# Target IP or IP:PORT\n# Example: 192.168.1.100\n# Example with port: 192.168.1.100:9025\n\n")
        print(f"{Y}[~]{W} '{IP_FILE}' created - edit it to set target.")
        return None, None

    with open(IP_FILE, "r") as f:
        lines = [l.strip() for l in f if l.strip() and not l.startswith("#")]
    if not lines:
        return None, None
    data = lines[0]
    if ":" in data:
        ip, port_str = data.split(":", 1)
        try:
            return ip.strip(), int(port_str.strip())
        except ValueError:
            return ip.strip(), None
    return data, None

def pick_payload(name):
    if os.sep in name or os.path.isabs(name):
        path = name
    else:
        path = os.path.join(PAYLOAD_DIR, name)
    if not os.path.isfile(path):
        print(f"{R}[!]{W} Payload not found: {path}")
        return None, None
    with open(path, "r") as f:
        code = f.read()
    return path, code

def send_payload(host, port, payload_data):
    size = struct.pack('<Q', len(payload_data))
    data = size + payload_data
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(TIMEOUT)
    try:
        sock.connect((host, port))
        sock.sendall(data)
        process_incoming_data(sock)
        return True
    except socket.timeout:
        print(f"{R}[!]{W} Connection timed out.")
    except ConnectionRefusedError:
        print(f"{R}[!]{W} Connection refused – is the loader running?")
    except OSError as e:
        print(f"{R}[!]{W} Network error: {e}")
    except Exception as e:
        print(f"{R}[!]{W} Unexpected error: {e}")
    finally:
        sock.close()
    return False

def process_incoming_data(sock):
    buffer = b""
    while True:
        ready, _, _ = select.select([sock], [], [], 1.0)
        if not ready:
            continue
        try:
            chunk = sock.recv(4096)
        except Exception as e:
            print(f"Receive error: {e}")
            break
        if not chunk:
            break
        buffer += chunk
        buffer = process_buffer(buffer)

def process_buffer(buffer):
    while True:
        if len(buffer) < MAGIC_LEN:
            break
        idx = buffer.find(MAGIC_VALUE)
        if idx == -1:
            break
        if len(buffer) < idx + MAGIC_LEN + SIGNAL_LEN + MCONTEXT_LEN:
            break
        start = idx + MAGIC_LEN
        magic = buffer[start:start + SIGNAL_LEN]
        mctx = buffer[start + SIGNAL_LEN:start + SIGNAL_LEN + MCONTEXT_LEN]
        print(buffer[:idx].decode("latin-1", errors="replace"), end="")
        process_crash_data(magic, mctx)
        buffer = buffer[start + SIGNAL_LEN + MCONTEXT_LEN:]
    if buffer and buffer.find(MAGIC_VALUE) == -1:
        print(buffer.decode("latin-1", errors="replace"), end="")
        buffer = b""
    return buffer

def process_crash_data(magic_data, mcontext_data):
    code, addr = struct.unpack("<QQ", magic_data)
    sig = SIGNALS.get(code, f"Unknown signal {code}")
    print(f"\n{R}[!] CRASH: {sig} at 0x{addr:016x}{W}")
    fmt = "<QQQQQQQQQQQQQQQQIHHQIHHQQQQQQ"
    regs = list(struct.unpack(fmt, mcontext_data[:struct.calcsize(fmt)]))
    names = ["onstack","rdi","rsi","rdx","rcx","r8","r9","rax","rbx","rbp",
             "r10","r11","r12","r13","r14","r15","trapno","fs","gs","addr",
             "flags","es","ds","err","rip","cs","rflags","rsp","ss"]
    print("  Register dump:")
    for i in range(1, len(names), 2):
        print(f"    {names[i]:>6}: 0x{regs[i]:016x}  {names[i+1]:>6}: 0x{regs[i+1]:016x}")
    print()

def send_command(host, port, command):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(TIMEOUT)
    try:
        sock.connect((host, port))
        sock.sendall(COMMAND_MAGIC + struct.pack("B", command))
        process_incoming_data(sock)
    except Exception as e:
        print(f"{R}[!] Command failed: {e}{W}")
    finally:
        sock.close()

def main():
    banner()
    ensure_payload_dir()

    # Parse arguments
    parser = argparse.ArgumentParser(description="Remote Lua Loader Payload Sender")
    group = parser.add_mutually_exclusive_group()
    parser.add_argument("ip", nargs="?", help="Target IP address")
    parser.add_argument("port", nargs="?", type=int, help="Target port number")
    group.add_argument("filepath", nargs="?", help="Payload file path")
    group.add_argument("--enable-signal-handler", action="store_true", help="Enable crash handler")
    group.add_argument("--disable-signal-handler", action="store_true", help="Disable crash handler")
    args = parser.parse_args()

    # Determine target
    host, port = None, None
    if args.ip:
        host = args.ip
        if args.port:
            port = args.port
    else:
        # Try IP file
        f_ip, f_port = read_target_file()
        if f_ip:
            host = f_ip
            port = f_port or PORT
        else:
            host = TARGET_IP
            port = PORT
    if not host:
        print(f"{R}[!] No target IP configured.{W}")
        sys.exit(1)

    # Handle signal handler commands
    if args.enable_signal_handler:
        send_command(host, port, ENABLE_SIGNAL_HANDLER)
        return
    if args.disable_signal_handler:
        send_command(host, port, DISABLE_SIGNAL_HANDLER)
        return

    # Otherwise send payload
    payload_name = args.filepath if args.filepath else DEFAULT_FILE
    path, code = pick_payload(payload_name)
    if code is None:
        print(f"{R}[!] Put a .lua payload in '{PAYLOAD_DIR}/' or specify a file.{W}")
        sys.exit(1)

    payload_bytes = code.encode("utf-8")
    print(f"{G}[+]{W} Payload : {path} ({len(payload_bytes)} bytes)")
    print(f"{G}[+]{W} Target  : {host}:{port}")
    print(f"{Y}[~]{W} Sending...")
    if send_payload(host, port, payload_bytes):
        print(f"{G}[+] Payload delivered.{W}")
    else:
        print(f"{R}[!] Sending failed.{W}")
        sys.exit(1)

if __name__ == "__main__":
    main()
