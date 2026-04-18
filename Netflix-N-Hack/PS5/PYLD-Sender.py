#!/usr/bin/env python3
"""
Netflix-N-Hack Payload Sender

Made by MexrlDev
"""

import os
import sys
import socket
import threading
import select
import ssl
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse
import struct

# ==============================
# USER CONFIGURATION – CHANGE THIS
# ==============================
PAYLOAD_FILE = "hello_world.js"   # <-- Set your payload filename here
# ==============================

# ------------------------------
# 1. Blocklist loading (hosts.txt)
# ------------------------------
BLOCKED_DOMAINS = set()

def load_blocked_domains():
    """Load domains from hosts.txt (same directory as script)."""
    global BLOCKED_DOMAINS
    script_dir = os.path.dirname(os.path.abspath(__file__))
    hosts_path = os.path.join(script_dir, "hosts.txt")

    try:
        with open(hosts_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split()
                domain = parts[-1] if parts else line
                BLOCKED_DOMAINS.add(domain.lower())
        print(f"[+] Loaded {len(BLOCKED_DOMAINS)} blocked domains from {hosts_path}")
    except FileNotFoundError:
        print(f"[!] WARNING: hosts.txt not found at {hosts_path}")
    except Exception as e:
        print(f"[!] ERROR loading hosts.txt: {e}")

def is_blocked(hostname: str) -> bool:
    """Check if hostname matches any blocked domain."""
    hostname_lower = hostname.lower()
    for blocked in BLOCKED_DOMAINS:
        if blocked in hostname_lower:
            return True
    return False

# ------------------------------
# 2. TLS SNI parser (for CONNECT blocking)
# ------------------------------
def extract_sni_from_client_hello(data: bytes) -> str | None:
    """Parse SNI extension from TLS ClientHello. Returns hostname or None."""
    try:
        if len(data) < 5 or data[0] != 0x16:
            return None
        record_len = int.from_bytes(data[3:5], 'big')
        if len(data) < 5 + record_len:
            return None

        handshake = data[5:5+record_len]
        if handshake[0] != 0x01:
            return None

        pos = 1 + 3  # skip type + length
        pos += 2     # client_version
        pos += 32    # random
        sess_id_len = handshake[pos]
        pos += 1 + sess_id_len
        cs_len = int.from_bytes(handshake[pos:pos+2], 'big')
        pos += 2 + cs_len
        comp_len = handshake[pos]
        pos += 1 + comp_len

        if pos + 2 > len(handshake):
            return None
        ext_len = int.from_bytes(handshake[pos:pos+2], 'big')
        pos += 2
        end_ext = pos + ext_len

        while pos + 4 <= end_ext:
            ext_type = int.from_bytes(handshake[pos:pos+2], 'big')
            ext_len = int.from_bytes(handshake[pos+2:pos+4], 'big')
            pos += 4
            if ext_type == 0x0000:  # server_name
                if pos + 2 > end_ext:
                    break
                list_len = int.from_bytes(handshake[pos:pos+2], 'big')
                pos += 2
                if pos + 3 > end_ext:
                    break
                name_type = handshake[pos]
                name_len = int.from_bytes(handshake[pos+1:pos+3], 'big')
                pos += 3
                if name_type == 0x00:
                    host_bytes = handshake[pos:pos+name_len]
                    return host_bytes.decode('utf-8', errors='ignore')
                pos += name_len
            else:
                pos += ext_len
        return None
    except Exception:
        return None

# ------------------------------
# 3. Custom HTTP Proxy Handler
# ------------------------------
class ProxyHTTPRequestHandler(BaseHTTPRequestHandler):
    timeout = 30

    def get_proxy_ip(self) -> bytes:
        """Return the IP address the client connected to (as bytes)."""
        return self.connection.getsockname()[0].encode("utf-8")

    def _get_destination(self):
        """
        Return (hostname, port, path, scheme) for the upstream server.
        Handles both absolute (proxy-style) and relative (origin-style) URLs.
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
                hostname, port = host.split(':', 1)
                port = int(port)
            else:
                hostname = host
                port = 80
            path = self.path
            scheme = 'https' if port == 443 else 'http'
            return hostname, port, path, scheme

    def do_CONNECT(self):
        """Handle CONNECT method for HTTPS tunneling with SNI blocking."""
        host, port = self.path.split(":")
        port = int(port)

        # Peek first TLS packet to extract SNI
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
            print(f"[*] Blocked HTTPS connection to: {sni}")
            return

        # Send 200 Connection Established
        self.send_response(200, "Connection Established")
        self.end_headers()

        try:
            # Consume the peeked data
            _ = self.connection.recv(len(first_data))

            # Connect to remote server with retry on network failure
            while True:
                try:
                    remote_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    remote_sock.settimeout(30)
                    remote_sock.connect((host, port))
                    break
                except socket.error:
                    time.sleep(1)

            # Bidirectional tunnel
            self._tunnel_bidirectional(self.connection, remote_sock)
        except Exception as e:
            print(f"[!] Tunnel failed for {host}:{port}: {e}")
        finally:
            self.connection.close()

    def _tunnel_bidirectional(self, client_sock, remote_sock):
        """Forward data between client and remote."""
        try:
            client_sock.settimeout(0.1)
            remote_sock.settimeout(0.1)
            while True:
                rlist, _, _ = select.select([client_sock, remote_sock], [], [], 1)
                if client_sock in rlist:
                    data = client_sock.recv(8192)
                    if not data:
                        break
                    remote_sock.sendall(data)
                if remote_sock in rlist:
                    data = remote_sock.recv(8192)
                    if not data:
                        break
                    client_sock.sendall(data)
        except Exception:
            pass
        finally:
            remote_sock.close()

    def do_GET(self):
        self._handle_request()

    def do_POST(self):
        self._handle_request()

    def do_HEAD(self):
        self._handle_request()

    def do_PUT(self):
        self._handle_request()

    def do_DELETE(self):
        self._handle_request()

    def _handle_request(self):
        """Process HTTP request and optionally inject response."""
        try:
            hostname, port, path, scheme = self._get_destination()
        except ValueError:
            self.send_error(400, "Missing Host header")
            return

        print(f"[*] {self.command} {scheme}://{hostname}:{port}{path}")

        # Block by domain
        if is_blocked(hostname):
            self.send_injected_response(404, b"uwu", {})
            print(f"[*] Blocked HTTP request to: {hostname}")
            return

        # Netflix corruption
        if "netflix" in hostname:
            self.send_injected_response(
                200, b"uwu",
                {"Content-Type": "application/x-msl+json"}
            )
            print(f"[*] Corrupted Netflix response for: {hostname}")
            return

        # --- DYNAMIC INJECTION PATHS ---
        script_dir = os.path.dirname(os.path.abspath(__file__))
        proxy_ip = self.get_proxy_ip()

        # Stage 1: Serve inject.js
        if "/js/inject.js" in path:
            inject_file = os.path.join(script_dir, "inject.js")
            self._inject_file_with_ip(inject_file, proxy_ip, "inject.js")
            return

        # Stage 2: Sends user payload file
        if "/js/payload.js" in path:
            payload_path = os.path.join(script_dir, PAYLOAD_FILE)
            self._inject_file_with_ip(payload_path, proxy_ip, PAYLOAD_FILE)
            return

        # Default: forward to real server
        self._forward_request()

    def _inject_file_with_ip(self, filepath, proxy_ip, desc, is_binary=False):
        """Read a local file, replace placeholder IP, and send as response."""
        try:
            with open(filepath, "rb") as f:
                content = f.read()
            content = content.replace(b"PLS_STOP_HARDCODING_IPS", proxy_ip)
            print(f"[+] Loaded {len(content)} bytes from {desc}")
            self.send_injected_response(200, content, {"Content-Type": "application/javascript"})
        except FileNotFoundError:
            error_msg = f"File not found: {desc}".encode()
            self.send_injected_response(404, error_msg, {"Content-Type": "text/plain"})
            print(f"[!] ERROR: {desc} not found at {filepath}")

    def send_injected_response(self, code, body_bytes, headers):
        """Send a custom HTTP response."""
        self.send_response(code)
        for k, v in headers.items():
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(body_bytes)))
        self.end_headers()
        self.wfile.write(body_bytes)

    def _forward_request(self):
        """Forward request to upstream server and relay response."""
        try:
            hostname, port, path, scheme = self._get_destination()

            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(30)
            while True:
                try:
                    sock.connect((hostname, port))
                    break
                except socket.error:
                    time.sleep(1)

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

            resp_data = b""
            while True:
                chunk = sock.recv(8192)
                if not chunk:
                    break
                resp_data += chunk
            sock.close()

            self.connection.sendall(resp_data)
        except Exception as e:
            print(f"[!] Forward error: {e}")
            self.send_error(502, "Bad Gateway")

    def log_message(self, format, *args):
        # Suppress default logging
        pass

# ------------------------------
# 4. Auto-detect local IP
# ------------------------------
def get_local_ip():
    """Return primary non-loopback IPv4 address."""
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

# ------------------------------
# 5. Main entry point
# ------------------------------
def main():
    load_blocked_domains()

    host = "0.0.0.0"
    port = 8080
    local_ip = get_local_ip()

    print(f"\n{'='*50}")
    print(f"Proxy running at http://{local_ip}:{port}")
    print(f"Set this as HTTP proxy on your device.")
    print(f"Payload file set to: {PAYLOAD_FILE}")
    print(f"Injection endpoints:")
    print(f"  /js/inject.js  -> inject.js")
    print(f"  /js/payload.js -> {PAYLOAD_FILE}")
    print(f"{'='*50}\n")

    server = ThreadingHTTPServer((host, port), ProxyHTTPRequestHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[!] Shutting down...")
        server.shutdown()

if __name__ == "__main__":
    main()
