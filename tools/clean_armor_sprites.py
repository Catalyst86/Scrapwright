"""Aggressively clean backgrounds on ALL player sprites using flood-fill from edges."""
from PIL import Image
import os, glob

PLAYER_DIR = r'C:\Users\danie\Desktop\roguelite\assets\sprites\player'
count = 0

for png_path in glob.glob(os.path.join(PLAYER_DIR, '**', '*.png'), recursive=True):
    img = Image.open(png_path).convert('RGBA')
    pixels = img.load()
    w, h = img.size

    # Step 1: Any pixel with alpha < 128 -> fully transparent
    changed = False
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < 128:
                pixels[x, y] = (0, 0, 0, 0)
                changed = True

    # Step 2: Flood fill from all edges - remove any connected low-contrast background
    # Mark all edge-connected pixels that look like background
    visited = set()
    queue = []

    # Add all edge pixels that are transparent
    for x in range(w):
        if pixels[x, 0][3] == 0:
            queue.append((x, 0))
        if pixels[x, h-1][3] == 0:
            queue.append((x, h-1))
    for y in range(h):
        if pixels[0, y][3] == 0:
            queue.append((0, y))
        if pixels[w-1, y][3] == 0:
            queue.append((w-1, y))

    # BFS to find all transparent-connected regions from edges
    while queue:
        cx, cy = queue.pop(0)
        if (cx, cy) in visited:
            continue
        if cx < 0 or cy < 0 or cx >= w or cy >= h:
            continue
        r, g, b, a = pixels[cx, cy]
        if a > 180:  # Solid pixel, stop flood
            continue
        visited.add((cx, cy))
        if a > 0:
            pixels[cx, cy] = (0, 0, 0, 0)
            changed = True
        for dx, dy in [(-1,0),(1,0),(0,-1),(0,1)]:
            nx, ny = cx+dx, cy+dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                queue.append((nx, ny))

    if changed:
        img.save(png_path)
        count += 1

print(f'Deep-cleaned {count} player sprite files')
