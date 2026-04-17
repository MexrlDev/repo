#!/usr/bin/env python3
"""
Mobile Netflix DownGrader Port

Ported by MexrlDev

Original by Earthonion
"""


import os
import sys
import socket
import select
import logging
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, urlunparse

# ------------------------------
# Logging setup
# ------------------------------
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)

# ------------------------------
# 1. Blocklist loading (hosts.txt)
# ------------------------------
BLOCKED_DOMAINS = set()

def load_blocked_domains():
    """Load domains from ../hosts.txt relative to script."""
    global BLOCKED_DOMAINS
    script_dir = os.path.dirname(os.path.abspath(__file__))
    hosts_path = os.path.join(script_dir, "..", "hosts.txt")

    try:
        with open(hosts_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split()
                domain = parts[-1] if parts else line
                BLOCKED_DOMAINS.add(domain.lower())
        logger.info(f"[+] Loaded {len(BLOCKED_DOMAINS)} blocked domains from {hosts_path}")
    except FileNotFoundError:
        logger.error(f"[!] WARNING: hosts.txt not found at {hosts_path}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"[!] ERROR loading hosts.txt: {e}")
        sys.exit(1)

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

    # PSN redirect constants
    EU_REDIRECT = "http://gs2.ww.prod.dl.playstation.net/gs2/ppkgo/prod/CUSA00127_00/108/f_2c294dc5a28917366a122cd32c2d03d000eb2aa27fe651231aaaf143ced665fd/f/EP4350-CUSA00127_00-NETFLIXPOLLUX001-A0153-V0100.json"
    US_REDIRECT = "http://gs2.ww.prod.dl.playstation.net/gs2/ppkgo/prod/CUSA00129_00/185/f_624fc32fe1d54c3062691b7ed42e78ab0c2bbbc73379a53f92fbff4b619d763a/f/UT0007-CUSA00129_00-NETFLIXPOLLUX001-A0153-V0100.json"
    JP_REDIRECT = "http://gs2.ww.prod.dl.playstation.net/gs2/ppkgo/prod/CUSA02988_00/104/f_9e6144c11eab87b3ebf340cce86ae456a135e80f848ead1185eb7a3ec19f0abe/f/JA0010-CUSA02988_00-NETFLIXPOLLUX001-A0153-V0100.json"
    NFLX_CUSAS = ["CUSA00127", "CUSA00129", "CUSA02988"]

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
        logger.info(f"[*] CONNECT {host}:{port} -> SNI: {sni}")

        if sni and is_blocked(sni):
            self.send_error(403, f"Blocked: {sni}")
            logger.info(f"[*] Blocked HTTPS connection to: {sni}")
            return

        # Send 200 Connection Established
        self.send_response(200, "Connection Established")
        self.end_headers()

        try:
            # Consume the peeked data
            _ = self.connection.recv(len(first_data))

            # Connect to remote server
            remote_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote_sock.settimeout(30)
            remote_sock.connect((host, port))

            # Bidirectional tunnel
            self._tunnel_bidirectional(self.connection, remote_sock)
        except Exception as e:
            logger.error(f"[!] Tunnel failed for {host}:{port}: {e}")
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
        """Process HTTP request and apply redirect/block rules."""
        parsed = urlparse(self.path)
        host = self.headers.get("Host", "")
        if not host:
            self.send_error(400, "Missing Host header")
            return

        full_url = f"{self.command} {self.path}"
        logger.info(f"[*] {full_url}")

        # --- Special PSN handling for gs2.ww.prod.dl.playstation.net over HTTP ---
        if self.path.startswith("http://") and "gs2.ww.prod.dl.playstation.net" in self.path:
            self._handle_psn_request(parsed)
            return

        # Also handle if scheme not in path but Host is that domain
        if "gs2.ww.prod.dl.playstation.net" in host:
            # Reconstruct URL with scheme
            scheme = "https" if self.headers.get("X-Forwarded-Proto") == "https" else "http"
            fake_url = f"{scheme}://{host}{parsed.path}"
            fake_parsed = urlparse(fake_url)
            self._handle_psn_request(fake_parsed)
            return

        # Block by domain (hosts.txt)
        if is_blocked(host):
            self.send_injected_response(404, b"uwu", {})
            logger.info(f"[*] Blocked HTTP request to: {host}")
            return

        # Netflix corruption (if not already handled)
        if "netflix" in host:
            self.send_injected_response(
                200, b"uwu",
                {"Content-Type": "application/x-msl+json"}
            )
            logger.info(f"[*] Corrupted Netflix response for: {host}")
            return

        # Default: forward to real server
        self._forward_request(host, parsed)

    def _handle_psn_request(self, parsed_url):
        """Apply PSN-specific redirects and blocks."""
        url_str = parsed_url.geturl()
        path = parsed_url.path
        host = parsed_url.netloc

        # Check if it's a JSON file for Netflix CUSA
        if path.endswith(".json"):
            for cusa in self.NFLX_CUSAS:
                if cusa in url_str:
                    redirect_url = None
                    if cusa == "CUSA00127":
                        redirect_url = self.EU_REDIRECT
                    elif cusa == "CUSA00129":
                        redirect_url = self.US_REDIRECT
                    elif cusa == "CUSA02988":
                        redirect_url = self.JP_REDIRECT
                    if redirect_url:
                        logger.info(f"[REDIRECT][{cusa}] {url_str}")
                        logger.info(f"        -> {redirect_url}")
                        # Change request URL and forward to new destination
                        new_parsed = urlparse(redirect_url)
                        self._forward_request(new_parsed.netloc, new_parsed)
                        return
            # If JSON but not matching CUSA, fall through to corruption

        # Check if it's a PKG file
        elif ".pkg" in url_str:
            allowed = any(cusa in url_str for cusa in self.NFLX_CUSAS)
            if allowed:
                logger.info(f"[PKG ALLOWED] {url_str}")
                self._forward_request(host, parsed_url)
            else:
                logger.info(f"[PKG BLOCKED - no matching CUSA] {url_str}")
                self.send_injected_response(403, b"Blocked PKG", {})
            return

        # All other requests to this host: corrupt response
        self.send_injected_response(
            200, b"uwu",
            {"Content-Type": "application/x-msl+json"}
        )
        logger.info(f"[*] Corrupted Game update response for: {host}")

    def send_injected_response(self, code, body_bytes, headers):
        """Send a custom HTTP response."""
        self.send_response(code)
        for k, v in headers.items():
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(body_bytes)))
        self.end_headers()
        self.wfile.write(body_bytes)

    def _forward_request(self, host, parsed_url):
        """
        Forward request to upstream server.
        host: netloc (e.g., example.com:80)
        parsed_url: urlparse result
        """
        try:
            # Split host and port
            if ":" in host:
                hostname, port = host.split(":")
                port = int(port)
            else:
                hostname = host
                port = 80

            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(30)
            sock.connect((hostname, port))

            # Build request line
            path = parsed_url.path or "/"
            if parsed_url.query:
                path += "?" + parsed_url.query
            request_line = f"{self.command} {path} HTTP/1.1\r\n"

            sock.sendall(request_line.encode())
            # Send headers (excluding hop-by-hop)
            for h, v in self.headers.items():
                if h.lower() not in ("connection", "proxy-connection", "keep-alive"):
                    sock.sendall(f"{h}: {v}\r\n".encode())
            sock.sendall(b"\r\n")

            # Send body if present
            if self.command in ("POST", "PUT") and self.headers.get("Content-Length"):
                content_len = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_len)
                sock.sendall(body)

            # Read and forward response
            resp_data = b""
            while True:
                chunk = sock.recv(8192)
                if not chunk:
                    break
                resp_data += chunk
            sock.close()

            self.connection.sendall(resp_data)
        except Exception as e:
            logger.error(f"[!] Forward error: {e}")
            self.send_error(502, "Bad Gateway")

    def log_message(self, format, *args):
        # Suppress default http.server logging (we use our own)
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

    logger.info(f"\n{'='*50}")
    logger.info(f"Proxy running at http://{local_ip}:{port}")
    logger.info(f"Set this as HTTP proxy on your device.")
    logger.info(f"{'='*50}\n")

    server = ThreadingHTTPServer((host, port), ProxyHTTPRequestHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("\n[!] Shutting down...")
        server.shutdown()

if __name__ == "__main__":
    main()
