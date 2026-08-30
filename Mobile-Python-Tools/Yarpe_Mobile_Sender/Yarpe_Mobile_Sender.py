#!/usr/bin/env python3
# Works on pythonica for iphone, PyCode for android. ans works for any payload listener.
# btw this isnt only for yarpe its for all paylaod listners. but i liked to give Yarpe its own mobile sender

import os
import sys
import socket

# ── CONFIG ─────────────────────────────
TARGET_IP     = "" #  IP shown on screen or whatever here btw..  
PORT          = 9025 # change this to whatever port you wanna send the script to.
PAYLOAD_DIR   = "payloads" # folder the payload is in btw
DEFAULT_FILE  = "payload.py" # payload name in the payload folder.. can be whatever extension you want. lua, js, py, etc..
IP_FILE       = "target_ip.txt"
TIMEOUT       = 6        
# ───────────────────────────────────────

G = '\033[92m'  
R = '\033[91m'  
Y = '\033[93m'  
C = '\033[96m'  
W = '\033[0m'   

def banner():
    print(C + "=" * 52)
    print("  Yarpe Payload Sender")
    print("=" * 52 + W)

def ensure_payload_dir():
    if not os.path.isdir(PAYLOAD_DIR):
        os.makedirs(PAYLOAD_DIR)
        print(f"{G}[+]{W} Created '{PAYLOAD_DIR}/' put your payloads inside.")

def read_target_file():
    if not os.path.isfile(IP_FILE):
        example_content = "# Put your target IP or IP:PORT here\n# Example: 192.168.1.100\n# Example with port: 192.168.1.100:9025\n\n"
        with open(IP_FILE, "w", encoding="utf-8") as f:
            f.write(example_content)
        print(f"{Y}[~]{W} '{IP_FILE}' not found, created default file.")
        return None, None

    with open(IP_FILE, "r", encoding="utf-8") as f:
        lines = f.readlines()

    valid_lines = [line.strip() for line in lines if line.strip() and not line.strip().startswith("#")]
    
    if not valid_lines:
        return None, None

    data = valid_lines[0]
    
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

    with open(path, "r", encoding="utf-8") as f:
        code = f.read()

    return path, code

def preflight_check(host, port):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(TIMEOUT)
        s.connect((host, port))
        s.close()
        return True
    except Exception:
        return False

def send(code, host, port):
    data = code.encode("utf-8")
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(TIMEOUT)
    try:
        s.connect((host, port))
        s.sendall(data)
        return True, len(data)
    except socket.timeout:
        return False, "Connection timed out."
    except ConnectionRefusedError:
        return False, "Connection refused."
    except OSError as e:
        if e.errno == 65:
            return False, "No route to host."
        return False, f"Network error: {e}"
    except Exception as e:
        return False, f"Unexpected error: {e}"
    finally:
        s.close()

def main():
    banner()
    ensure_payload_dir()

    if len(sys.argv) >= 2:
        payload_name = sys.argv[1]
    else:
        payload_name = DEFAULT_FILE

    path, code = pick_payload(payload_name)
    if code is None:
        print(f"\n{R}[!]{W} Put your payload in: {PAYLOAD_DIR}/")
        sys.exit(1)

    print(f"{G}[+]{W} Payload : {path} ({len(code.encode('utf-8'))} bytes)")

    host = TARGET_IP
    port = PORT
    source = "script config"

    file_ip, file_port = read_target_file()
    if file_ip:
        host = file_ip
        source = IP_FILE
        if file_port:
            port = file_port

    if len(sys.argv) >= 3:
        cli_arg = sys.argv[2]
        if ":" in cli_arg:
            cli_ip, cli_port = cli_arg.split(":", 1)
            host = cli_ip.strip()
            try:
                port = int(cli_port.strip())
            except ValueError:
                pass
        else:
            host = cli_arg.strip()
        source = "command line"

    if not host:
        print(f"\n{R}[!]{W} No IP configured.")
        print("    1. Edit TARGET_IP in script or fill target_ip.txt")
        sys.exit(1)

    print(f"{G}[+]{W} Target  : {host}:{port}  (from {source})\n")

    print(f"{Y}[~]{W} Checking connection to {host}:{port} ...")
    if not preflight_check(host, port):
        print(f"{R}[!]{W} Can't reach {host}:{port}\n")
        sys.exit(1)

    print(f"{G}[+]{W} Port is open.\n")

    print(f"{Y}[~]{W} Sending payload...")
    ok, result = send(code, host, port)

    if ok:
        print(f"{G}[+]{W} Sent {result} bytes, payload delivered!")
    else:
        print(f"{R}[!]{W} Send failed: {result}")
        sys.exit(1)

if __name__ == "__main__":
    main()
