"""
Mobile WebSocket Secure Echo Server

Original by Earthonion

Ported by MexrlDev
"""

import ssl
import asyncio
import socket
import struct
import hashlib
import base64
from asyncio import StreamReader, StreamWriter

# --- SSL Context ---
ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ssl_context.load_cert_chain(certfile="cert.pem", keyfile="key.pem")
# Generate cert with:
# openssl req -x509 -newkey rsa:4096 -nodes -keyout key.pem -out cert.pem -days 365 -subj "/CN=localhost"

WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

def get_local_ip():
    """Return the local Wi-Fi IP address."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except:
        return "127.0.0.1"

async def websocket_handshake(reader: StreamReader, writer: StreamWriter) -> bool:
    request = await reader.readuntil(b"\r\n\r\n")
    headers = request.decode(errors="ignore").split("\r\n")
    if not headers[0].startswith("GET"):
        return False
    key = None
    for h in headers:
        if h.lower().startswith("sec-websocket-key:"):
            key = h.split(":", 1)[1].strip()
            break
    if not key:
        return False
    accept = base64.b64encode(hashlib.sha1((key + WS_GUID).encode()).digest()).decode()
    response = (
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Accept: {accept}\r\n"
        "\r\n"
    )
    writer.write(response.encode())
    await writer.drain()
    return True

async def read_frame(reader: StreamReader):
    try:
        header = await reader.readexactly(2)
    except asyncio.IncompleteReadError:
        return None, None
    byte1, byte2 = header[0], header[1]
    opcode = byte1 & 0x0F
    masked = (byte2 & 0x80) != 0
    payload_len = byte2 & 0x7F
    if payload_len == 126:
        ext = await reader.readexactly(2)
        payload_len = struct.unpack(">H", ext)[0]
    elif payload_len == 127:
        ext = await reader.readexactly(8)
        payload_len = struct.unpack(">Q", ext)[0]
    mask_key = await reader.readexactly(4) if masked else None
    payload = await reader.readexactly(payload_len)
    if masked:
        payload = bytes(b ^ mask_key[i % 4] for i, b in enumerate(payload))
    return opcode, payload

async def send_frame(writer: StreamWriter, payload: bytes, opcode: int = 0x1):
    frame = bytearray()
    frame.append(0x80 | opcode)
    length = len(payload)
    if length <= 125:
        frame.append(length)
    elif length <= 65535:
        frame.append(126)
        frame.extend(struct.pack(">H", length))
    else:
        frame.append(127)
        frame.extend(struct.pack(">Q", length))
    frame.extend(payload)
    writer.write(frame)
    await writer.drain()

async def handle_client(reader: StreamReader, writer: StreamWriter):
    addr = writer.get_extra_info("peername")
    print(f"Client connected from {addr[0]}:{addr[1]}")
    if not await websocket_handshake(reader, writer):
        writer.close()
        return
    try:
        while True:
            opcode, payload = await read_frame(reader)
            if opcode is None:
                break
            if opcode == 0x1:
                print(payload.decode("utf-8", errors="replace"))
            elif opcode == 0x8:
                break
            elif opcode == 0x9:
                await send_frame(writer, payload, 0xA)
    except (ConnectionResetError, BrokenPipeError):
        pass
    finally:
        print("Client disconnected")
        writer.close()
        await writer.wait_closed()

async def main():
    local_ip = get_local_ip()
    server = await asyncio.start_server(handle_client, "0.0.0.0", 1337, ssl=ssl_context)
    print(f"[+] WebSocket server running on wss://{local_ip}:1337")
    print("[+] Press Ctrl+C to stop.\n")
    try:
        async with server:
            await server.serve_forever()
    except asyncio.CancelledError:
        pass

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[!] Shutting down...")
