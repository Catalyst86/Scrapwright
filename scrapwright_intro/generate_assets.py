"""
Generate pixel art assets for Scrapwright intro video.
Uses PixelLab API for backgrounds, PIL for props/effects.
Run: python generate_assets.py
"""
import requests, base64, os, math, random
from PIL import Image, ImageDraw

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
BASE_URL = 'https://api.pixellab.ai/v1'
ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'assets')
os.makedirs(ASSETS, exist_ok=True)

def save_if_missing(name, img):
    path = os.path.join(ASSETS, name)
    if os.path.exists(path):
        print(f'SKIP {name}')
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(f'OK   {name}')

def gen_api(name, desc, w=64, h=64, no_bg=True):
    """Try PixelLab API, return True if successful."""
    path = os.path.join(ASSETS, name)
    if os.path.exists(path):
        print(f'SKIP {name}')
        return True
    print(f'API  {name}...', end=' ', flush=True)
    try:
        r = requests.post(f'{BASE_URL}/generate-image-pixflux', headers=HEADERS, json={
            'description': desc,
            'image_size': {'width': w, 'height': h},
            'outline': 'single color black outline',
            'shading': 'medium shading',
            'detail': 'medium detail',
            'no_background': no_bg
        }, timeout=120)
        d = r.json()
        if 'image' in d:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'wb') as f:
                f.write(base64.b64decode(d['image']['base64']))
            print('OK')
            return True
        else:
            print(f'ERR: {str(d)[:80]}')
            return False
    except Exception as e:
        print(f'ERR: {e}')
        return False


# ═══════════════════════════════════════════════════════
# PROCEDURAL BACKGROUNDS (PIL-generated pixel art)
# ═══════════════════════════════════════════════════════

def make_junkyard_bg(name, w=384, h=216, red_sky=False, panic=False):
    """Generate a pixel art junkyard background procedurally."""
    path = os.path.join(ASSETS, name)
    if os.path.exists(path):
        print(f'SKIP {name}')
        return

    random.seed(hash(name) % 2**32)
    img = Image.new('RGBA', (w, h))
    draw = ImageDraw.Draw(img)

    # Sky gradient
    if panic:
        sky_top = (40, 5, 5)
        sky_bot = (120, 25, 10)
    elif red_sky:
        sky_top = (60, 10, 10)
        sky_bot = (150, 40, 15)
    else:
        sky_top = (25, 20, 35)
        sky_bot = (50, 40, 45)

    ground_line = h * 2 // 3

    for y in range(ground_line):
        t = y / ground_line
        r = int(sky_top[0] + (sky_bot[0] - sky_top[0]) * t)
        g = int(sky_top[1] + (sky_bot[1] - sky_top[1]) * t)
        b = int(sky_top[2] + (sky_bot[2] - sky_top[2]) * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    # Ground
    ground_colors = [(70, 55, 40), (60, 48, 35), (55, 42, 30), (65, 50, 38)]
    for y in range(ground_line, h):
        t = (y - ground_line) / (h - ground_line)
        base = ground_colors[0]
        r = int(base[0] * (1 - t * 0.3))
        g = int(base[1] * (1 - t * 0.3))
        b = int(base[2] * (1 - t * 0.3))
        for x in range(w):
            noise = random.randint(-8, 8)
            draw.point((x, y), fill=(max(0, r + noise), max(0, g + noise), max(0, b + noise), 255))

    # Scrap metal piles (rectangles + shapes)
    scrap_colors = [
        (90, 70, 50), (100, 75, 55), (80, 60, 45),  # rust
        (70, 70, 75), (85, 85, 90), (60, 60, 65),    # metal grey
        (110, 80, 40), (95, 65, 35),                   # dark rust
    ]

    # Background scrap silhouettes (distant)
    for _ in range(8):
        sx = random.randint(0, w)
        sy = random.randint(ground_line - 30, ground_line + 10)
        sw = random.randint(15, 40)
        sh = random.randint(20, 50)
        c = random.choice(scrap_colors[:3])
        c_dark = (c[0] // 2, c[1] // 2, c[2] // 2, 255)
        draw.rectangle([sx, sy - sh, sx + sw, sy], fill=c_dark)

    # Foreground scrap objects
    for _ in range(15):
        sx = random.randint(-10, w)
        sy = random.randint(ground_line - 5, h - 10)
        shape_type = random.choice(['rect', 'pipe', 'gear'])
        c = random.choice(scrap_colors)

        if shape_type == 'rect':
            sw = random.randint(8, 25)
            sh = random.randint(5, 15)
            draw.rectangle([sx, sy, sx + sw, sy + sh], fill=(*c, 255), outline=(c[0]//2, c[1]//2, c[2]//2, 255))
        elif shape_type == 'pipe':
            pw = random.randint(20, 50)
            ph = random.randint(3, 6)
            draw.rectangle([sx, sy, sx + pw, sy + ph], fill=(*c, 255))
            draw.ellipse([sx - 2, sy - 1, sx + 4, sy + ph + 1], fill=(c[0]+20, c[1]+20, c[2]+20, 255))
        elif shape_type == 'gear':
            gr = random.randint(4, 10)
            draw.ellipse([sx - gr, sy - gr, sx + gr, sy + gr], outline=(*c, 255), width=2)
            draw.ellipse([sx - gr//2, sy - gr//2, sx + gr//2, sy + gr//2], fill=(c[0]//2, c[1]//2, c[2]//2, 255))

    # Dark clouds (if not panic)
    if not panic:
        for _ in range(5):
            cx = random.randint(0, w)
            cy = random.randint(5, ground_line // 3)
            cw = random.randint(30, 80)
            ch = random.randint(8, 20)
            cloud_c = (30, 25, 35, 60) if not red_sky else (60, 20, 15, 80)
            draw.ellipse([cx - cw//2, cy - ch//2, cx + cw//2, cy + ch//2], fill=cloud_c)

    # Red glow from bottom for red_sky variants
    if red_sky or panic:
        for y in range(h - 40, h):
            alpha = int(80 * ((y - (h - 40)) / 40))
            draw.line([(0, y), (w, y)], fill=(200, 60, 20, alpha))

    # Falling debris for panic
    if panic:
        for _ in range(20):
            dx = random.randint(0, w)
            dy = random.randint(0, h)
            ds = random.randint(2, 5)
            draw.rectangle([dx, dy, dx + ds, dy + ds], fill=(80, 60, 40, 180))

    img.save(path)
    print(f'OK   {name} (procedural)')


# ═══════════════════════════════════════════════════════
# PROCEDURAL PROPS
# ═══════════════════════════════════════════════════════

def make_boot_silhouette():
    img = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Simple boot shape - dark silhouette
    # Sole
    draw.rectangle([10, 45, 58, 55], fill=(15, 15, 15, 255))
    # Heel
    draw.rectangle([10, 35, 25, 55], fill=(15, 15, 15, 255))
    # Ankle
    draw.rectangle([15, 15, 35, 45], fill=(15, 15, 15, 255))
    # Toe
    draw.rectangle([35, 40, 58, 50], fill=(15, 15, 15, 255))
    save_if_missing('boot_silhouette.png', img)

def make_tin_can():
    img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Rusty tin can
    draw.rectangle([8, 10, 24, 26], fill=(140, 110, 80, 255), outline=(90, 70, 50, 255))
    draw.ellipse([8, 8, 24, 14], fill=(160, 130, 100, 255), outline=(90, 70, 50, 255))
    draw.line([(10, 17), (22, 17)], fill=(120, 95, 70, 255))
    save_if_missing('tin_can.png', img)

def make_artifact(name, size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2

    # Glow aura
    for r in range(size // 2, 2, -1):
        alpha = int(80 * (r / (size // 2)))
        # Cyan + gold mix
        cr = int(40 + 180 * (r / (size // 2)))
        cg = int(180 + 50 * (r / (size // 2)))
        cb = int(200 - 100 * (r / (size // 2)))
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(cr, cg, cb, alpha))

    # Jagged metal shard
    s = size // 4
    points = [
        (cx, cy - s),
        (cx + s, cy - s // 2),
        (cx + s // 2, cy + s // 3),
        (cx + s, cy + s),
        (cx - s // 3, cy + s // 2),
        (cx - s, cy),
    ]
    draw.polygon(points, fill=(180, 200, 220, 255), outline=(0, 200, 220, 255))
    # Inner highlight
    inner = [(p[0] * 0.7 + cx * 0.3, p[1] * 0.7 + cy * 0.3) for p in points[:4]]
    draw.polygon([(int(x), int(y)) for x, y in inner], fill=(220, 240, 255, 200))

    save_if_missing(name, img)

def make_ground_crack():
    img = Image.new('RGBA', (128, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Main crack line with branches
    random.seed(555)
    points = [(0, 32)]
    x, y = 0, 32
    while x < 128:
        x += random.randint(5, 15)
        y += random.randint(-8, 8)
        y = max(10, min(54, y))
        points.append((x, y))
    draw.line(points, fill=(20, 15, 10, 255), width=2)
    # Branches
    for i in range(2, len(points) - 1, 2):
        bx, by = points[i]
        blen = random.randint(8, 20)
        bdir = random.choice([-1, 1])
        draw.line([(bx, by), (bx + blen // 2, by + blen * bdir)],
                  fill=(30, 20, 15, 200), width=1)
    save_if_missing('ground_crack.png', img)

def make_silhouette_person():
    img = Image.new('RGBA', (48, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    c = (15, 15, 15, 240)
    # Head
    draw.ellipse([18, 2, 30, 14], fill=c)
    # Body
    draw.rectangle([20, 14, 28, 38], fill=c)
    # Arms (running pose)
    draw.line([(20, 18), (12, 30)], fill=c, width=3)
    draw.line([(28, 22), (38, 16)], fill=c, width=3)
    # Legs (running stride)
    draw.line([(22, 38), (14, 58)], fill=c, width=3)
    draw.line([(26, 38), (36, 54)], fill=c, width=3)
    save_if_missing('silhouette_person_running.png', img)

def make_magic_burst():
    size = 128
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    # Expanding rings of light
    for r in range(size // 2, 5, -3):
        t = r / (size // 2)
        alpha = int(200 * t * t)
        # White center -> cyan edge
        cr = int(255 * t + 100 * (1 - t))
        cg = int(255 * t + 220 * (1 - t))
        cb = 255
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(cr, cg, cb, alpha), width=2)
    # Bright center
    draw.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(255, 255, 255, 255))
    save_if_missing('magic_burst.png', img)

def make_magic_particle():
    img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Small glowing dot
    for r in range(12, 1, -1):
        alpha = int(150 * (1 - r / 12))
        draw.ellipse([16 - r, 16 - r, 16 + r, 16 + r], fill=(100, 220, 240, alpha))
    draw.ellipse([14, 14, 18, 18], fill=(200, 255, 255, 255))
    save_if_missing('magic_particle.png', img)


# ═══════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════

if __name__ == '__main__':
    print('=== Generating Scrapwright Intro Assets ===\n')

    # Backgrounds (procedural)
    make_junkyard_bg('bg_junkyard.png')
    make_junkyard_bg('bg_junkyard_wide.png', w=500)
    make_junkyard_bg('bg_red_sky.png', red_sky=True)
    make_junkyard_bg('bg_panic_sky.png', panic=True)

    # Try API for backgrounds as higher quality alternatives
    print('\n--- Attempting API backgrounds (may timeout) ---')
    gen_api('bg_junkyard_api.png',
            'pixel art junkyard wasteland scene scattered scrap metal rusty pipes dark moody sky brown grey steampunk',
            w=128, h=72, no_bg=False)
    gen_api('bg_red_sky_api.png',
            'pixel art junkyard red ominous sky orange glow apocalyptic cracks ground dark',
            w=128, h=72, no_bg=False)

    # Props (procedural)
    print('\n--- Generating procedural props ---')
    make_boot_silhouette()
    make_tin_can()
    make_artifact('artifact_glow.png', 32)
    make_artifact('artifact_large.png', 64)
    make_ground_crack()
    make_silhouette_person()
    make_magic_burst()
    make_magic_particle()

    print('\n=== Asset generation complete! ===')
    print(f'Assets directory: {ASSETS}')
    print('Note: If API backgrounds succeeded, copy bg_*_api.png over bg_*.png for higher quality.')
