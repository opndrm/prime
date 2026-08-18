#!/usr/bin/env python3
"""One-frame, token-gated PPM server on a Unix socket. No input path exists."""
import os, socket, subprocess

PATH = "/run/buzz-container/view.sock"
TOKEN = os.environ["BUZZ_CONTAINER_VIEW_TOKEN"].encode()
try: os.unlink(PATH)
except FileNotFoundError: pass
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(PATH)
os.chmod(PATH, 0o600)
server.listen(1)
while True:
    client, _ = server.accept()
    with client:
        # A stream read may split even this small local credential. Collect a
        # single newline-terminated value instead of treating a partial read
        # as an authentication failure.
        supplied = bytearray()
        while len(supplied) <= len(TOKEN):
            chunk = client.recv(len(TOKEN) + 1 - len(supplied))
            if not chunk:
                break
            supplied.extend(chunk)
            if supplied.endswith(b"\n"):
                break
        if supplied.rstrip(b"\r\n") != TOKEN: continue
        # A failed screenshot fails closed for this one request. It must not
        # terminate the owner-only socket server or expose diagnostics.
        try:
            frame = subprocess.check_output(
                ["import", "-display", ":99", "-window", "root", "-depth", "8", "ppm:-"],
                stderr=subprocess.DEVNULL,
            )
        except subprocess.CalledProcessError:
            continue
        # The native owner may close a stale request while a frame is being
        # produced. That is not a server failure: retain the one-way viewer
        # for the next fresh request.
        try:
            client.sendall(frame)
        except BrokenPipeError:
            continue
