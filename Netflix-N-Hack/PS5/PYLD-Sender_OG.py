#!/usr/bin/env python3
"""
Payload Sender (PS5)

Made by MexrlDev
"""

import os
import socket
from http.server import HTTPServer, BaseHTTPRequestHandler

# ============================================================
# CONFIGURATION – EDIT HERE
# ============================================================
PAYLOAD_NAME = "hello_world.js"   # Name of the file inside payloads/
PORT = 9020                       # Port to listen on (PS5 often uses 9020)
BIND_ADDRESS = "0.0.0.0"          # Bind to all interfaces
# ============================================================

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PAYLOADS_DIR = os.path.join(SCRIPT_DIR, "payloads")
PAYLOAD_PATH = os.path.join(PAYLOADS_DIR, PAYLOAD_NAME)

# Content-Type mapping based on file extension
CONTENT_TYPES = {
    ".js":   "application/javascript",
    ".html": "text/html",
    ".css":  "text/css",
    ".json": "application/json",
    ".txt":  "text/plain",
    ".bin":  "application/octet-stream",
    ".elf":  "application/octet-stream",
    ".bin":  "application/octet-stream",
}

def get_content_type(filename):
    ext = os.path.splitext(filename)[1].lower()
    return CONTENT_TYPES.get(ext, "application/octet-stream")

class PayloadHandler(BaseHTTPRequestHandler):
    """Handles all requests by serving the configured payload."""

    def do_GET(self):
        self._serve_payload()

    def do_POST(self):
        self._serve_payload()

    def do_HEAD(self):
        if not os.path.isfile(PAYLOAD_PATH):
            self.send_response(404)
            self.end_headers()
            return
        content_type = get_content_type(PAYLOAD_NAME)
        file_size = os.path.getsize(PAYLOAD_PATH)
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(file_size))
        self.end_headers()

    def _serve_payload(self):
        """Read the payload file and send it to the client."""
        if not os.path.isfile(PAYLOAD_PATH):
            self.send_error(404, f"Payload '{PAYLOAD_NAME}' not found")
            print(f"[!] Payload file missing: {PAYLOAD_PATH}")
            return

        try:
            with open(PAYLOAD_PATH, "rb") as f:
                content = f.read()

            content_type = get_content_type(PAYLOAD_NAME)
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(content)))
            # PS5 may expect certain CORS headers; add if needed
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(content)

            print(f"[+] Served {PAYLOAD_NAME} ({len(content)} bytes) to {self.client_address[0]}")
        except Exception as e:
            self.send_error(500, f"Internal server error: {e}")
            print(f"[!] Error serving payload: {e}")

    def log_message(self, format, *args):
        """Suppress default logging (we print our own)."""
        pass

def get_local_ip():
    """Return the primary local IP address."""
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

def main():
    print(f"\n{'='*50}")
    print(f"PS5 Payload Sender – serving '{PAYLOAD_NAME}'")
    print(f"Folder: {PAYLOADS_DIR}")
    print(f"Listening on http://{get_local_ip()}:{PORT}")
    print(f"{'='*50}\n")

    # Ensure payloads directory exists
    os.makedirs(PAYLOADS_DIR, exist_ok=True)

    if not os.path.isfile(PAYLOAD_PATH):
        print(f"[!] Warning: '{PAYLOAD_NAME}' not found in payloads/ folder.")
        print(f"[!] Place the file at: {PAYLOAD_PATH}")
    else:
        size = os.path.getsize(PAYLOAD_PATH)
        print(f"[+] Payload ready ({size} bytes)")

    server = HTTPServer((BIND_ADDRESS, PORT), PayloadHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[!] Shutting down...")
        server.shutdown()

if __name__ == "__main__":
    main()
