"""
Netflix-N-Hack Phone-Port

Original by Earthonion

Ported by MexrlDev
"""

import os
import sys
import socket
import threading
import urllib.request
import urllib.error
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

# -------------------- Configuration --------------------
LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = 8080

# -------------------- Load Blocked Domains --------------------
BLOCKED = set()
hosts_path = Path(__file__).parent / "hosts.txt"
if hosts_path.exists():
    with open(hosts_path, "r") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                parts = line.split()
                domain = parts[-1] if parts else line
                BLOCKED.add(domain.lower())
    print(f"[+] Loaded {len(BLOCKED)} blocked domains from hosts.txt")
else:
    print(f"[!] WARNING: hosts.txt not found at {hosts_path}")

def is_blocked(hostname):
    host_lower = hostname.lower()
    return any(blocked in host_lower for blocked in BLOCKED)

# -------------------- Proxy Handler --------------------
class ProxyHandler(BaseHTTPRequestHandler):
    timeout = 30

    def log_message(self, format, *args):
        pass

    def do_CONNECT(self):
        host, port = self.path.split(":")
        port = int(port)

        if is_blocked(host):
            self.send_error(403, f"Blocked domain: {host}")
            print(f"[*] Blocked CONNECT: {host}:{port}")
            return

        print(f"[*] CONNECT tunnel to {host}:{port}")
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as remote:
                remote.settimeout(self.timeout)
                remote.connect((host, port))
                self.send_response(200, "Connection Established")
                self.end_headers()
                self._tunnel(self.connection, remote)
        except Exception as e:
            print(f"[!] CONNECT error: {e}")
            self.send_error(502, "Bad Gateway")

    def _tunnel(self, client, remote):
        def forward(src, dst):
            try:
                while True:
                    data = src.recv(8192)
                    if not data:
                        break
                    dst.sendall(data)
            except:
                pass
            finally:
                src.close()
                dst.close()

        t1 = threading.Thread(target=forward, args=(client, remote))
        t2 = threading.Thread(target=forward, args=(remote, client))
        t1.daemon = t2.daemon = True
        t1.start(); t2.start()
        t1.join(self.timeout); t2.join(self.timeout)

    def do_GET(self): self._handle_request()
    def do_POST(self): self._handle_request()
    def do_PUT(self): self._handle_request()
    def do_DELETE(self): self._handle_request()
    def do_HEAD(self): self._handle_request()

    def _get_proxy_ip(self):
        return self.server.server_address[0].encode()

    def _handle_request(self):
        host = self.headers.get("Host")
        if not host:
            self.send_error(400, "Missing Host header")
            return

        hostname = host.split(":")[0]

        if is_blocked(hostname):
            self.send_error(404, "Blocked")
            print(f"[*] Blocked HTTP: {host}{self.path}")
            return

        proxy_ip = self._get_proxy_ip()

        # Netflix corruption
        if "netflix" in hostname.lower():
            self.send_response(200)
            self.send_header("Content-Type", "application/x-msl+json")
            self.end_headers()
            self.wfile.write(b"uwu")
            print(f"[*] Corrupted Netflix response for: {hostname}")
            return

        # JS interceptions
        if "/js/common/config/text/config.text.lruderrorpage" in self.path:
            self._serve_file("inject_elfldr_automated.js", "application/javascript", proxy_ip)
            return
        if "/js/lapse.js" in self.path:
            self._serve_file(Path("payloads") / "lapse.js", "application/javascript", proxy_ip)
            return
        if "/js/elf_loader.js" in self.path:
            self._serve_file(Path("payloads") / "elf_loader.js", "application/javascript", proxy_ip)
            return
        if "/js/elfldr.elf" in self.path:
            self._serve_file(Path("payloads") / "elfldr.elf", "application/octet-stream", proxy_ip)
            return
        if "/js/ps4/inject_auto_bundle.js" in self.path:
            self._serve_file(Path("PS4") / "inject_auto_bundle.js", "application/javascript", proxy_ip)
            return

        # Default forward
        self._forward_request()

    def _serve_file(self, rel_path, content_type, proxy_ip):
        file_path = Path(__file__).parent / rel_path
        print(f"[*] Serving: {file_path}")
        if file_path.exists():
            try:
                data = file_path.read_bytes()
                if b"PLS_STOP_HARDCODING_IPS" in data:
                    data = data.replace(b"PLS_STOP_HARDCODING_IPS", proxy_ip)
                self.send_response(200)
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", len(data))
                self.end_headers()
                self.wfile.write(data)
            except Exception as e:
                self.send_error(500, f"File error: {e}")
        else:
            self.send_error(404, f"File not found: {rel_path}")

    def _forward_request(self):
        host = self.headers.get("Host")
        if not host:
            self.send_error(400, "Missing Host header")
            return

        hostname = host.split(":")[0]

        try:
            resolved_ip = socket.gethostbyname(hostname)
        except socket.gaierror as e:
            print(f"[!] DNS resolution failed for {hostname}: {e}")
            self.send_error(502, f"DNS resolution failed: {e}")
            return

        url = f"http://{resolved_ip}{self.path}"
        headers = dict(self.headers)
        for h in ["Proxy-Connection", "Connection", "Keep-Alive",
                  "Proxy-Authenticate", "Proxy-Authorization",
                  "TE", "Trailer", "Transfer-Encoding", "Upgrade"]:
            headers.pop(h, None)
        headers["Host"] = host

        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len) if content_len > 0 else None

        print(f"[>] {self.command} {url} (Host: {host})")

        try:
            req = urllib.request.Request(url, data=body, headers=headers, method=self.command)
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                self.send_response(resp.status)
                for key, val in resp.getheaders():
                    if key.lower() not in ["connection", "keep-alive", "proxy-authenticate",
                                           "proxy-authorization", "te", "trailer",
                                           "transfer-encoding", "upgrade"]:
                        self.send_header(key, val)
                self.end_headers()
                while chunk := resp.read(8192):
                    self.wfile.write(chunk)
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for key, val in e.headers.items():
                if key.lower() not in ["connection", "keep-alive", "proxy-authenticate",
                                       "proxy-authorization", "te", "trailer",
                                       "transfer-encoding", "upgrade"]:
                    self.send_header(key, val)
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            print(f"[!] Forward error: {e}")
            self.send_error(502, f"Gateway Error: {e}")

# -------------------- Threaded Server --------------------
class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

def get_local_ip():
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except:
        return "127.0.0.1"

def main():
    bind_ip = get_local_ip()
    server_address = (LISTEN_HOST, LISTEN_PORT)
    httpd = ThreadedHTTPServer(server_address, ProxyHandler)
    print(f"[+] Proxy bound to {bind_ip}:{LISTEN_PORT}")
    print("[+] Press Ctrl+C to stop.\n")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[!] Shutting down...")
        httpd.shutdown()

if __name__ == "__main__":
    main()
