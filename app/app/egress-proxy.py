#!/usr/bin/env python3
"""HTTPS-only, public-IP-only CONNECT relay for an isolated guest via Unix socket."""
import ipaddress
import os
import select
import socket
import socketserver
import sys

SOCKET = sys.argv[1]
if os.path.exists(SOCKET):
    os.unlink(SOCKET)


def public_addresses(host):
    if not host or len(host) > 253 or any(c in host for c in '/\\@%\x00'):
        return []
    try:
        addresses = socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)
    except (socket.gaierror, UnicodeError, OSError):
        return []
    result = []
    for family, _, _, _, address in addresses:
        ip = ipaddress.ip_address(address[0])
        # All DNS answers must be public. A mixed private/public response is denied.
        if not ip.is_global:
            return []
        result.append((family, address))
    return result


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        client = self.request
        client.settimeout(8)
        line = bytearray()
        try:
            while len(line) < 4096 and not line.endswith(b'\r\n\r\n'):
                data = client.recv(1)
                if not data:
                    return
                line.extend(data)
            if len(line) >= 4096:
                return self.deny()
            first = line.split(b'\r\n', 1)[0].decode('ascii')
            parts = first.split()
            if len(parts) != 3 or parts[0] != 'CONNECT' or parts[2] != 'HTTP/1.1':
                return self.deny()
            host, sep, port = parts[1].rpartition(':')
            if sep != ':' or port != '443':
                return self.deny()
            if host.startswith('[') and host.endswith(']'):
                host = host[1:-1]
            candidates = public_addresses(host)
            if not candidates:
                return self.deny()
            remote = None
            for family, address in candidates:
                try:
                    remote = socket.socket(family, socket.SOCK_STREAM)
                    remote.settimeout(5)
                    remote.connect(address)  # pin to the vetted IP, not a second DNS lookup
                    break
                except OSError:
                    if remote:
                        remote.close()
                    remote = None
            if remote is None:
                return self.deny()
            with remote:
                client.sendall(b'HTTP/1.1 200 Connection Established\r\n\r\n')
                client.setblocking(False)
                remote.setblocking(False)
                pair = (client, remote)
                while True:
                    readable, _, _ = select.select(pair, [], [], 120)
                    if not readable:
                        return
                    for incoming in readable:
                        try:
                            data = incoming.recv(65536)
                        except OSError:
                            return
                        if not data:
                            return
                        outgoing = remote if incoming is client else client
                        outgoing.setblocking(True)
                        try:
                            outgoing.sendall(data)
                        finally:
                            outgoing.setblocking(False)
        except (OSError, ValueError, UnicodeError):
            return

    def deny(self):
        try:
            self.request.sendall(b'HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n')
        except OSError:
            pass


class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True

with Server(SOCKET, Handler) as server:
    os.chmod(SOCKET, 0o600)
    server.serve_forever()
