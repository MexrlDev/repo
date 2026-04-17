#!/usr/bin/env python3
"""
Netflix-N-Hack Mobile Port

Ported by MexrlDev

Original by earthonion
"""

import os
import sys
import socket
import threading
import select
import ssl
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse
import struct
import time

# ------------------------------
# 1. Blocklist loading (hosts.txt)
# ------------------------------
BLOCKED_DOMAINS = set()

def load_blocked_domains():
    """Load domains from hosts.txt (same dir or parent dir)"""
    global BLOCKED_DOMAINS
    script_dir = os.path.dirname(os.path.abspath(__file__))
    possible_paths = [
        os.path.join(script_dir, "hosts.txt"),
        os.path.join(script_dir, "..", "hosts.txt"),
    ]
    hosts_path = None
    for p in possible_paths:
        if os.path.exists(p):
            hosts_path = p
            break

    if not hosts_path:
        print(f"[!] hosts.txt not found. Tried: {possible_paths}")
        print("[!] Continuing without blocking list.")
        return

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
    except Exception as e:
        print(f"[!] ERROR loading hosts.txt: {e}")

def is_blocked(hostname: str) -> bool:
    """Check if hostname matches any blocked domain"""
    hostname_lower = hostname.lower()
    for blocked in BLOCKED_DOMAINS:
        if blocked in hostname_lower:
            return True
    return False

# ------------------------------
# 2. TLS SNI parser (for CONNECT blocking)
# ------------------------------
def extract_sni_from_client_hello(data: bytes) -> str | None:
    """
    Parse the SNI extension from a TLS ClientHello message.
    Returns hostname string or None if not present or parse fails.
    """
    try:
        # TLS record layer
        if len(data) < 5:
            return None
        if data[0] != 0x16:  # handshake
            return None
        # record length
        record_len = int.from_bytes(data[3:5], 'big')
        if len(data) < 5 + record_len:
            return None

        handshake = data[5:5+record_len]
        if handshake[0] != 0x01:  # client_hello
            return None
        # skip handshake header (1 byte type + 3 bytes length)
        # handshake length is at offset 1..3
        # client_hello structure:
        #   legacy_version (2)
        #   random (32)
        #   session_id_length (1) + session_id
        #   cipher_suites_length (2) + cipher_suites
        #   compression_methods_length (1) + compression_methods
        #   extensions_length (2) + extensions

        pos = 1 + 3  # skip type+length
        # client_version (2)
        pos += 2
        # random (32)
        pos += 32
        # session_id
        sess_id_len = handshake[pos]
        pos += 1 + sess_id_len
        # cipher_suites
        cs_len = int.from_bytes(handshake[pos:pos+2], 'big')
        pos += 2 + cs_len
        # compression_methods
        comp_len = handshake[pos]
        pos += 1 + comp_len

        # extensions
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
                # server_name extension: list length (2) + ServerNameList
                if pos + 2 > end_ext:
                    break
                list_len = int.from_bytes(handshake[pos:pos+2], 'big')
                pos += 2
                # parse first entry
                if pos + 3 > end_ext:
                    break
                name_type = handshake[pos]
                name_len = int.from_bytes(handshake[pos+1:pos+3], 'big')
                pos += 3
                if name_type == 0x00:  # hostname
                    host_bytes = handshake[pos:pos+name_len]
                    return host_bytes.decode('utf-8', errors='ignore')
                pos += name_len
            else:
                pos += ext_len
        return None
    except Exception:
        return None

# ------------------------------
# 3. TCP tunnel with SNI inspection (CONNECT method)
# ------------------------------
def handle_tunnel(client_sock, client_addr):
    """
    Read first TLS ClientHello from client, check SNI.
    If blocked -> close connection.
    Else -> connect to real server and start bidirectional forwarding.
    """
    try:
        # Peek first bytes to read ClientHello
        client_sock.settimeout(5)
        first_data = client_sock.recv(4096)
        if not first_data:
            client_sock.close()
            return

        sni = extract_sni_from_client_hello(first_data)
        target_host = sni if sni else "unknown"
        print(f"[*] CONNECT SNI: {target_host}")

        if sni and is_blocked(sni):
            print(f"[*] BLOCKED HTTPS: {sni}")
            client_sock.close()
            return

    except Exception as e:
        print(f"[!] Tunnel error: {e}")
        client_sock.close()
        return

# ------------------------------
# 4. Custom HTTP Proxy Handler
# ------------------------------
class ProxyHTTPRequestHandler(BaseHTTPRequestHandler):
    timeout = 30

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
        # Parse host:port from path
        host, port = self.path.split(":")
        port = int(port)
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

        # Send 200 Connection Established
        self.send_response(200, "Connection Established")
        self.end_headers()

        # Now consume the peeked data and start tunneling
        try:
            _ = self.connection.recv(len(first_data))

            # Connect to remote server
            remote_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote_sock.settimeout(30)
            remote_sock.connect((host, port))

            # Forward data both ways
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

        # Check blacklist
        if is_blocked(hostname):
            self.send_injected_response(404, b"Blocked", {"Content-Type": "text/plain"})
            print(f"[*] BLOCKED HTTP: {hostname}")
            return

        # Special handling for Netflix
        if "netflix" in hostname:
            self.send_injected_response(
                200, b"uwu",
                {"Content-Type": "application/x-msl+json"}
            )
            print(f"[*] Corrupted Netflix: {hostname}")
            return

        # Injection paths
        if "/js/common/config/text/config.text.lruderrorpage" in path:
            inject_file = os.path.join(os.path.dirname(__file__), "inject_auto_bundle.js")
            self._inject_file(inject_file, "inject_auto_bundle.js")
            return

        if "/js/lapse.js" in path:
            inject_file = os.path.join(os.path.dirname(__file__), "payloads", "lapse.js")
            self._inject_file(inject_file, "lapse.js")
            return

        # Otherwise forward request to real server
        self._forward_request()

    def _inject_file(self, filepath, desc):
        """Respond with content from local file."""
        try:
            with open(filepath, "rb") as f:
                content = f.read()
            self.send_injected_response(200, content, {"Content-Type": "application/javascript"})
            print(f"[+] Injected {desc} ({len(content)} bytes)")
        except FileNotFoundError:
            self.send_injected_response(
                404,
                f"File not found: {desc}".encode(),
                {"Content-Type": "text/plain"}
            )
            print(f"[!] Missing file: {filepath}")

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

            # Create socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(30)
            sock.connect((hostname, port))

            # Build request line (use absolute URL if originally absolute)
            if self.path.startswith(('http://', 'https://')):
                request_line = f"{self.command} {self.path} HTTP/1.1\r\n"
            else:
                request_line = f"{self.command} {path} HTTP/1.1\r\n"

            # Send headers (excluding hop-by-hop)
            sock.sendall(request_line.encode())
            for h, v in self.headers.items():
                if h.lower() not in ("connection", "proxy-connection", "keep-alive"):
                    sock.sendall(f"{h}: {v}\r\n".encode())
            sock.sendall(b"\r\n")

            # Send body if present
            if self.command in ("POST", "PUT") and self.headers.get("Content-Length"):
                content_len = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_len)
                sock.sendall(body)

            # Read response
            resp_data = b""
            while True:
                chunk = sock.recv(8192)
                if not chunk:
                    break
                resp_data += chunk
            sock.close()

            # Relay response back to client
            self.connection.sendall(resp_data)
        except Exception as e:
            print(f"[!] Forward error: {e}")
            self.send_error(502, "Bad Gateway")

    def log_message(self, format, *args):
        # Suppress default logging (we have our own)
        pass

# ------------------------------
# 5. Auto-detect local IP
# ------------------------------
def get_local_ip():
    """Return primary non-loopback IPv4 address."""
    try:
        # Connect to a public address to determine default route IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        # Fallback: try to get from hostname
        try:
            return socket.gethostbyname(socket.gethostname())
        except:
            return "127.0.0.1"

# ------------------------------
# 6. Main entry point
# ------------------------------
def main():
    load_blocked_domains()

    host = "0.0.0.0"
    port = 8080
    local_ip = get_local_ip()

    print(f"\n{'='*50}")
    print(f"Proxy running at http://{local_ip}:{port}")
    print(f"Set this as HTTP proxy on your device.")
    print(f"{'='*50}\n")

    server = ThreadingHTTPServer((host, port), ProxyHTTPRequestHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[!] Shutting down...")
        server.shutdown()

if __name__ == "__main__":
    main()
