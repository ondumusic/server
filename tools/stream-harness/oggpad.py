# Pads an Ogg file to a size with empty pages (27-byte headers, no packets) that
# carry the last page's granule position and continue its sequence, then zeros for
# the remainder under 27 bytes. Usage: oggpad.py in out total_size [zeros]
import struct, sys
def crc_table():
    t = []
    for i in range(256):
        r = i << 24
        for _ in range(8): r = ((r << 1) ^ 0x04C11DB7) if r & 0x80000000 else (r << 1)
        t.append(r & 0xFFFFFFFF)
    return t
T = crc_table()
def crc(data):
    r = 0
    for b in data: r = ((r << 8) & 0xFFFFFFFF) ^ T[((r >> 24) ^ b) & 0xFF]
    return r
def last_page(data):
    pos = data.rfind(b"OggS")
    while pos >= 0:
        seg = data[pos + 26]; body = sum(data[pos + 27: pos + 27 + seg])
        if pos + 27 + seg + body == len(data): return pos
        pos = data.rfind(b"OggS", 0, pos)
    raise SystemExit("no final page")
def empty_page(granule, serial, seq):
    head = b"OggS" + bytes([0, 0]) + struct.pack("<qIIIB", granule, serial, seq, 0, 0)
    return head[:22] + struct.pack("<I", crc(head)) + head[26:]
src, dst, total = sys.argv[1], sys.argv[2], int(sys.argv[3])
data = open(src, "rb").read()
if len(sys.argv) > 4 and sys.argv[4] == "zeros":
    out = data + bytes(total - len(data))
else:
    p = last_page(data); granule, serial, seq = struct.unpack("<qII", data[p + 6: p + 22])
    pad = total - len(data); pages = b"".join(empty_page(granule, serial, seq + 1 + i) for i in range(pad // 27))
    out = data + pages + bytes(pad - len(pages))
    # sanity: our crc reproduces the real last page's checksum
    seg = data[p + 26]; page = bytearray(data[p: p + 27 + seg + sum(data[p + 27: p + 27 + seg])])
    real = struct.unpack("<I", page[22:26])[0]; page[22:26] = b"\0\0\0\0"
    assert crc(page) == real, "crc mismatch against the real page"
open(dst, "wb").write(out); print(f"{dst}: {len(data)} -> {len(out)} bytes")
