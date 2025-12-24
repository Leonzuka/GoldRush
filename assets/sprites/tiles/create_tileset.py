#!/usr/bin/env python
import struct

def create_png():
    # Minimal PNG: 64x16, 4 tiles side by side
    # Each tile is 16x16
    width, height = 64, 16
    
    # PNG signature
    png = b'\x89PNG\r\n\x1a\n'
    
    # IHDR chunk (image header)
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)  # RGB, 8-bit
    png += b'\x00\x00\x00\x0d' + b'IHDR' + ihdr
    png += struct.pack('>I', 0x72983478)  # CRC (precalculated for this IHDR)
    
    # IDAT chunk (image data) - simple solid colors
    # Each scanline needs a filter byte (0 = no filter)
    rows = []
    for y in range(height):
        row = bytearray([0])  # Filter byte
        for x in range(width):
            # Tile 0 (0-15): Dirt brown #8B4513
            if x < 16:
                row.extend([0x8B, 0x45, 0x13])
            # Tile 1 (16-31): Stone gray #696969
            elif x < 32:
                row.extend([0x69, 0x69, 0x69])
            # Tile 2 (32-47): Bedrock dark #2F2F2F
            elif x < 48:
                row.extend([0x2F, 0x2F, 0x2F])
            # Tile 3 (48-63): Empty/transparent (darker)
            else:
                row.extend([0x1F, 0x1F, 0x1F])
        rows.append(bytes(row))
    
    raw_data = b''.join(rows)
    
    # Compress with zlib
    import zlib
    compressed = zlib.compress(raw_data, 9)
    
    # IDAT chunk
    png += struct.pack('>I', len(compressed)) + b'IDAT' + compressed
    crc = zlib.crc32(b'IDAT' + compressed) & 0xffffffff
    png += struct.pack('>I', crc)
    
    # IEND chunk
    png += b'\x00\x00\x00\x00' + b'IEND' + b'\xae\x42\x60\x82'
    
    return png

with open('terrain_tileset.png', 'wb') as f:
    f.write(create_png())
print("Tileset created: 64x16 PNG")
