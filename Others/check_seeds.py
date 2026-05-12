from pathlib import Path
'''
Check if seeds contain png that has color type palette (3), and small bit-depth
'''
for path in Path("seeds").glob("*.png"):
    data = path.read_bytes()

    width = int.from_bytes(data[16:20], "big")
    height = int.from_bytes(data[20:24], "big")
    depth = data[24]
    color_type = data[25]

    if color_type == 3:
        if depth in (1, 2, 4):
            print(path, "width: ", width, "height: ", height, "depth: ", depth, "color_type: ", color_type)