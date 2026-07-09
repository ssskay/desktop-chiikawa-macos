#!/usr/bin/env python3
"""Repack a Godot 4.x .pck with a modified main.gd.

Replaces the compiled script (main.gdc + main.gd.remap) inside an existing
pack with a plain-source main.gd, which export-template runtimes load happily.

Usage:
    python3 repack_pck.py <original.pck> <main.gd> <output.pck>

The output pck drops into ChiikawaPet.app/Contents/Resources/ChiikawaPet.pck.
Re-sign the app afterwards:  codesign --force --deep --sign - ChiikawaPet.app
"""
import hashlib
import struct
import sys


def pad(n: int, a: int = 4) -> int:
    return (a - n % a) % a


def repack(src_path: str, script_path: str, out_path: str) -> None:
    src = open(src_path, "rb").read()
    assert src[:4] == b"GDPC", "not a Godot pck"

    file_base_old = struct.unpack_from("<Q", src, 24)[0]
    off = 32 + 16 * 4
    count = struct.unpack_from("<I", src, off)[0]
    off += 4

    entries = []
    for _ in range(count):
        plen = struct.unpack_from("<I", src, off)[0]
        off += 4
        name = src[off:off + plen].rstrip(b"\x00").decode()
        off += plen
        foff, fsize = struct.unpack_from("<QQ", src, off)
        off += 36  # offset(8) + size(8) + md5(16) + flags(4)
        entries.append([name, src[file_base_old + foff:file_base_old + foff + fsize]])
    print(f"read {len(entries)} files from {src_path}")

    entries = [e for e in entries if e[0] not in {"main.gdc", "main.gd.remap"}]
    entries.append(["main.gd", open(script_path, "rb").read()])
    entries.sort(key=lambda e: e[0])

    dir_size = 4 + sum(4 + len(n.encode()) + pad(len(n.encode())) + 36 for n, _ in entries)
    file_base = 96 + dir_size
    file_base += pad(file_base, 32)

    out_dir, blob = b"", b""
    for name, data in entries:
        nb = name.encode()
        out_dir += struct.pack("<I", len(nb) + pad(len(nb))) + nb + b"\x00" * pad(len(nb))
        out_dir += struct.pack("<QQ", len(blob), len(data))
        out_dir += hashlib.md5(data).digest() + struct.pack("<I", 0)
        blob += data + b"\x00" * pad(len(data), 32)

    out = struct.pack("<IIIIII", 0x43504447, 2, 4, 4, 1, 0x2)  # GDPC v2, Godot 4.4.1, rel file_base
    out += struct.pack("<Q", file_base) + b"\x00" * 64
    out += struct.pack("<I", len(entries)) + out_dir
    out += b"\x00" * (file_base - len(out)) + blob

    open(out_path, "wb").write(out)
    print(f"wrote {out_path} ({len(out)} bytes, {len(entries)} files)")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    repack(sys.argv[1], sys.argv[2], sys.argv[3])
