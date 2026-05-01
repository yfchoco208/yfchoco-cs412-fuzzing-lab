from pathlib import Path

for path in Path("seeds").glob("*.png"):
    data = path.read_bytes()

    if len(data) < 26:
        continue

    if data[:8] != b"\x89PNG\r\n\x1a\n":
        continue

    if data[12:16] != b"IHDR":
        continue

    width = int.from_bytes(data[16:20], "big")
    height = int.from_bytes(data[20:24], "big")
    bit_depth = data[24]
    color_type = data[25]

    if color_type == 3 and bit_depth in (1, 2, 4):
        print(path, "width=", width, "height=", height,
              "bit_depth=", bit_depth, "color_type=", color_type)