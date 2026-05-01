from pathlib import Path
import shutil

src_dir = Path("seeds")
dst_dir = Path("seeds_relevant")

dst_dir.mkdir(exist_ok=True)

count = 0

for path in src_dir.glob("*.png"):
    data = path.read_bytes()

    width = int.from_bytes(data[16:20], "big")
    height = int.from_bytes(data[20:24], "big")
    depth = data[24]
    color_type = data[25]

    if color_type == 3:
        if depth in (1, 2, 4):
            shutil.copy2(path, dst_dir / path.name)
            print(path, "width:", width, "height:", height, "depth:", depth, "color_type:", color_type)
            count += 1

print(f"\nCopied {count} seeds")