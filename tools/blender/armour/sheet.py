"""Tile review PNGs side by side with numpy and a stdlib PNG reader: python3 sheet.py out.png a.png b.png ..."""
import sys
import zlib
import struct
import numpy as np


def read(path):
    data = open(path, "rb").read()
    pos, idat, w, h, ct, bd = 8, b"", 0, 0, 0, 0
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            w, h, bd, ct = struct.unpack(">IIBB", chunk[:10])
        elif kind == b"IDAT":
            idat += chunk
        pos += n + 12
    ch = {2: 3, 6: 4}[ct]
    raw = zlib.decompress(idat)
    stride = w * ch * (bd // 8)
    out = np.zeros((h, stride), dtype=np.uint8)
    bpp = ch * (bd // 8)
    prev = np.zeros(stride, dtype=np.int32)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = np.frombuffer(raw, np.uint8, stride, y * (stride + 1) + 1).astype(np.int32)
        if f == 1:
            cur = line.copy()
            for i in range(bpp, stride):
                cur[i] = (cur[i] + cur[i - bpp]) & 255
        elif f == 2:
            cur = (line + prev) & 255
        elif f == 3:
            cur = line.copy()
            for i in range(stride):
                cur[i] = (cur[i] + ((cur[i - bpp] if i >= bpp else 0) + prev[i]) // 2) & 255
        elif f == 4:
            cur = line.copy()
            for i in range(stride):
                a = cur[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                cur[i] = (cur[i] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        else:
            cur = line
        out[y] = cur
        prev = cur
    arr = out.reshape(h, w, -1)
    if bd == 16:
        arr = arr[:, :, ::2]
    return arr[:, :, :3]


def write(path, arr):
    h, w, _ = arr.shape
    raw = b"".join(b"\0" + arr[y].tobytes() for y in range(h))

    def chunk(k, d):
        return struct.pack(">I", len(d)) + k + d + struct.pack(">I", zlib.crc32(k + d))

    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


imgs = [read(p) for p in sys.argv[2:]]
H = max(i.shape[0] for i in imgs)
imgs = [np.pad(i, ((0, H - i.shape[0]), (0, 0), (0, 0))) for i in imgs]
write(sys.argv[1], np.concatenate(imgs, axis=1))
