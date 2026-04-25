#!/usr/bin/env python3
"""
Netflix-N-Hack Mobile Port REWORKED

Ported by MexrlDev

Original by earthonion
"""

import os
import sys
import socket
import struct
import time
import select
import ssl
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

# ============================================================
# CONFIGURATION
# ============================================================
MAIN_PAYLOAD_FILE = "inject_auto_bundle.js"            # e.g. "inject.js"
SECONDARY_PAYLOAD_FILE = "lapse.js"       # e.g. "lapse.js" - replace with "Snake.py" for the snake game i made)

# Path pattern that triggers the main injection.
# The proxy will serve MAIN_PAYLOAD_FILE whenever this substring appears in the request path.
MAIN_INJECT_PATH_TRIGGER = "/js/common/config/text/config.text.lruderrorpage"

# ============================================================
# 1. Blocklist management (hosts.txt)
# ============================================================
BLOCKED_DOMAINS: set[str] = set()

def load_blocked_domains() -> None:
    """Load domains to block from hosts.txt (same directory as py)."""
    global BLOCKED_DOMAINS
    script_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(script_dir, "hosts.txt"),
        os.path.join(script_dir, "..", "hosts.txt"),
    ]
    hosts_path = None
    for p in candidates:
        if os.path.exists(p):
            hosts_path = p
            break

    if not hosts_path:
        print(f"[!] hosts.txt not found. Tried: {candidates}")
        print("[!] Continuing without blocking list.")
        return

    try:
        with open(hosts_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                # Format: "0.0.0.0 example.com" or just "example.com"
                parts = line.split()
                domain = parts[-1] if parts else line
                BLOCKED_DOMAINS.add(domain.lower())
        print(f"[+] Loaded {len(BLOCKED_DOMAINS)} blocked domains from {hosts_path}")
    except Exception as e:
        print(f"[!] ERROR loading hosts.txt: {e}")

def is_blocked(hostname: str) -> bool:
    """Return True if hostname matches any blocked domain."""
    hostname_lower = hostname.lower()
    return any(blocked in hostname_lower for blocked in BLOCKED_DOMAINS)


# ============================================================
# 2. TLS SNI parser (used for CONNECT tunnel blocking)
# ============================================================
def extract_sni_from_client_hello(data: bytes) -> str | None:
    """
    Extract the Server Name Indication (SNI) from a TLS ClientHello.
    Returns the hostname string or None if parsing fails.
    """
    try:
        if len(data) < 5 or data[0] != 0x16:          # TLS handshake
            return None

        record_len = int.from_bytes(data[3:5], 'big')
        if len(data) < 5 + record_len:
            return None

        handshake = data[5:5 + record_len]
        if handshake[0] != 0x01:                      # ClientHello
            return None

        pos = 1 + 3                                   # skip message type + length
        pos += 2                                      # client_version
        pos += 32                                     # random
        sess_id_len = handshake[pos]
        pos += 1 + sess_id_len
        # cipher suites
        cs_len = int.from_bytes(handshake[pos:pos+2], 'big')
        pos += 2 + cs_len
        # compression methods
        comp_len = handshake[pos]
        pos += 1 + comp_len

        # Extensions
        if pos + 2 > len(handshake):
            return None
        ext_total_len = int.from_bytes(handshake[pos:pos+2], 'big')
        pos += 2
        end_ext = pos + ext_total_len

        while pos + 4 <= end_ext:
            ext_type = int.from_bytes(handshake[pos:pos+2], 'big')
            ext_len = int.from_bytes(handshake[pos+2:pos+4], 'big')
            pos += 4
            if ext_type == 0x0000:                    # server_name
                if pos + 2 > end_ext:
                    break
                list_len = int.from_bytes(handshake[pos:pos+2], 'big')
                pos += 2
                if pos + 3 > end_ext:
                    break
                name_type = handshake[pos]
                name_len = int.from_bytes(handshake[pos+1:pos+3], 'big')
                pos += 3
                if name_type == 0x00:                 # host_name
                    host_bytes = handshake[pos:pos+name_len]
                    return host_bytes.decode('utf-8', errors='ignore')
                pos += name_len
            else:
                pos += ext_len
        return None
    except Exception:
        return None

# ============================================================
# 3. HTTP Proxy Request Handler
# ============================================================
class ProxyHTTPRequestHandler(BaseHTTPRequestHandler):
    timeout = 30

    def _get_destination(self) -> tuple[str, int, str, str]:
        """
        Parse the request to obtain (hostname, port, path, scheme).
        Handles both absolute (proxy-style) and relative URLs.
        """
        if self.path.startswith(('http://', 'https://')):
            parsed = urlparse(self.path)
            hostname = parsed.hostname
            port = parsed.port or (443 if parsed.scheme == 'https' else 80)
            path = parsed.path or '/'
            if parsed.query:
                path += '?' + parsed.query
            return hostname, port, path, parsed.scheme
        else:
            host = self.headers.get('Host', '')
            if not host:
                raise ValueError("Missing Host header")
            if ':' in host:
                hostname, port_str = host.split(':', 1)
                port = int(port_str)
            else:
                hostname = host
                port = 80
            path = self.path
            scheme = 'https' if port == 443 else 'http'
            return hostname, port, path, scheme

    # ---------- CONNECT (HTTPS tunneling) ----------
    def do_CONNECT(self) -> None:
        host, port_str = self.path.split(":")
        port = int(port_str)
        self.connection.settimeout(5)

        try:
            first_data = self.connection.recv(4096, socket.MSG_PEEK)
        except socket.timeout:
            self.send_error(504, "Gateway Timeout")
            return

        sni = extract_sni_from_client_hello(first_data)
        print(f"[*] CONNECT {host}:{port} -> SNI: {sni}")

        if sni and is_blocked(sni):
            self.send_error(403, f"Blocked: {sni}")
            print(f"[*] BLOCKED HTTPS: {sni}")
            return

        self.send_response(200, "Connection Established")
        self.end_headers()

        try:
            _ = self.connection.recv(len(first_data))
            remote = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote.settimeout(30)
            remote.connect((host, port))
            self._tunnel_bidirectional(self.connection, remote)
        except Exception as e:
            print(f"[!] Tunnel failed for {host}:{port}: {e}")
        finally:
            self.connection.close()

    def _tunnel_bidirectional(self, client: socket.socket, remote: socket.socket) -> None:
        try:
            client.settimeout(0.1)
            remote.settimeout(0.1)
            while True:
                rlist, _, _ = select.select([client, remote], [], [], 1)
                if client in rlist:
                    data = client.recv(8192)
                    if not data:
                        break
                    remote.sendall(data)
                if remote in rlist:
                    data = remote.recv(8192)
                    if not data:
                        break
                    client.sendall(data)
        except Exception:
            pass
        finally:
            remote.close()

    # ---------- HTTP methods ----------
    def do_GET(self) -> None:    self._handle_request()
    def do_POST(self) -> None:   self._handle_request()
    def do_HEAD(self) -> None:   self._handle_request()
    def do_PUT(self) -> None:    self._handle_request()
    def do_DELETE(self) -> None: self._handle_request()

    def _get_payload_content(self, filename: str) -> bytes:
        """
        Search for a payload file in multiple locations:
          1. Current working directory
          2. Same directory as this script
          3. script_dir/payloads/
        """
        script_dir = os.path.dirname(os.path.abspath(__file__))
        candidates = [
            os.path.join(os.curdir, filename),
            os.path.join(script_dir, filename),
            os.path.join(script_dir, "payloads", filename),
        ]
        for path in candidates:
            if os.path.isfile(path):
                try:
                    with open(path, "rb") as f:
                        print(f"[*] Found {filename} at {path}")
                        return f.read()
                except Exception as e:
                    print(f"[!] Error reading {path}: {e}")
        return b""

    def _handle_request(self) -> None:
        try:
            hostname, port, path, scheme = self._get_destination()
        except ValueError:
            self.send_error(400, "Missing Host header")
            return

        print(f"[*] {self.command} {scheme}://{hostname}:{port}{path}")

        # 1. Blocklist check
        if is_blocked(hostname):
            self.send_injected_response(404, b"Blocked", {"Content-Type": "text/plain"})
            print(f"[*] BLOCKED HTTP: {hostname}")
            return

        # 2. Main injection trigger (Netflix error page)
        if MAIN_INJECT_PATH_TRIGGER in path:
            main_content = self._get_payload_content(MAIN_PAYLOAD_FILE)
            if not main_content:
                self.send_injected_response(404, f"{MAIN_PAYLOAD_FILE} not found".encode(),
                                            {"Content-Type": "text/plain"})
                print(f"[!] Missing {MAIN_PAYLOAD_FILE}")
                return

            # Merge secondary payload if it exists
            secondary_content = self._get_payload_content(SECONDARY_PAYLOAD_FILE)
            if secondary_content:
                combined = main_content + b"\n\n" + secondary_content
                total = len(main_content) + len(secondary_content)
                print(f"[+] Serving combined payload: {MAIN_PAYLOAD_FILE} + {SECONDARY_PAYLOAD_FILE} ({total} bytes)")
            else:
                combined = main_content
                print(f"[+] Serving main payload only: {MAIN_PAYLOAD_FILE} ({len(main_content)} bytes) – {SECONDARY_PAYLOAD_FILE} not found")

            self.send_injected_response(200, combined,
                                        {"Content-Type": "application/javascript"})
            return

        # 3. Direct request for secondary payload (backup)
        #    Intercept any path that ends with the secondary payload file name
        if path.rstrip("/").endswith("/" + SECONDARY_PAYLOAD_FILE) or \
           "/payloads/" + SECONDARY_PAYLOAD_FILE in path:
            content = self._get_payload_content(SECONDARY_PAYLOAD_FILE)
            if content:
                self.send_injected_response(200, content,
                                            {"Content-Type": "application/javascript"})
                print(f"[+] Injected {SECONDARY_PAYLOAD_FILE} ({len(content)} bytes) from direct request")
            else:
                self.send_injected_response(404, f"{SECONDARY_PAYLOAD_FILE} not found".encode(),
                                            {"Content-Type": "text/plain"})
                print(f"[!] {SECONDARY_PAYLOAD_FILE} not found for direct request")
            return

        # 4. Netflix MSL corruption (only for other Netflix paths)
        if "netflix" in hostname:
            self.send_injected_response(200, b"uwu",
                                        {"Content-Type": "application/x-msl+json"})
            print(f"[*] Corrupted Netflix: {hostname}")
            return

        # 5. Normal forward
        self._forward_request()

    def send_injected_response(self, code: int, body: bytes,
                               headers: dict[str, str]) -> None:
        self.send_response(code)
        for k, v in headers.items():
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _forward_request(self) -> None:
        try:
            hostname, port, path, scheme = self._get_destination()

            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(30)
            sock.connect((hostname, port))

            if self.path.startswith(('http://', 'https://')):
                request_line = f"{self.command} {self.path} HTTP/1.1\r\n"
            else:
                request_line = f"{self.command} {path} HTTP/1.1\r\n"

            sock.sendall(request_line.encode())
            for h, v in self.headers.items():
                if h.lower() not in ("connection", "proxy-connection", "keep-alive"):
                    sock.sendall(f"{h}: {v}\r\n".encode())
            sock.sendall(b"\r\n")

            if self.command in ("POST", "PUT") and self.headers.get("Content-Length"):
                content_len = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_len)
                sock.sendall(body)

            response = b""
            while True:
                chunk = sock.recv(8192)
                if not chunk:
                    break
                response += chunk
            sock.close()
            self.connection.sendall(response)
        except Exception as e:
            print(f"[!] Forward error: {e}")
            self.send_error(502, "Bad Gateway")

    def log_message(self, format, *args):
        pass


# ============================================================
# 4. Utility: local IP detection
# ============================================================
def get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        try:
            return socket.gethostbyname(socket.gethostname())
        except:
            return "127.0.0.1"


# ============================================================
# 5. Main entry point
# ============================================================
def main() -> None:
    load_blocked_domains()

    host = "0.0.0.0"
    port = 8080
    local_ip = get_local_ip()

    print(f"\n{'='*50}")
    print(f"Netflix-n-Hack Mobile Proxy")
    print(f"Main payload : {MAIN_PAYLOAD_FILE}")
    print(f"Secondary    : {SECONDARY_PAYLOAD_FILE}")
    print(f"Listening on {local_ip} : {port}")
    print(f"Set this as your PlayStation proxy.")
    print(f"{'='*50}\n")

    server = ThreadingHTTPServer((host, port), ProxyHTTPRequestHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[!] Shutting down...")
        server.shutdown()

if __name__ == "__main__":
    main()
