"""
Render animated title card for Scrapwright intro.
Uses the junkyard sunset frame as background + PixelLab animated sleeping puppy.
"""
import os
import math
import random
import subprocess
from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REFS_DIR = os.path.join(SCRIPT_DIR, "kling_refs")
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "output")
FRAMES_DIR = os.path.join(OUTPUT_DIR, "title_frames")
os.makedirs(FRAMES_DIR, exist_ok=True)

# Check for user-provided background frame
BG_CANDIDATES = [
    os.path.join(SCRIPT_DIR, "kling_videos", "title_bg_frame.png"),
    os.path.join(REFS_DIR, "title_bg_frame.png"),
    os.path.join(REFS_DIR, "title_bg_final.png"),
]

# Load REAL game sprite idle frames
IDLE_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "assets", "sprites", "player", "bandana", "idle", "south")
DOG_FRAMES = []
for i in range(4):
    path = os.path.join(IDLE_DIR, f"frame_{i:03d}.png")
    if os.path.exists(path):
        DOG_FRAMES.append(Image.open(path).convert("RGBA"))

WIDTH, HEIGHT = 1920, 1080
FPS = 30
DURATION = 5
TOTAL_FRAMES = FPS * DURATION

GOLD = (218, 165, 32)
BRIGHT_GOLD = (255, 215, 60)
CYAN = (0, 220, 220)


def draw_pixel_text(draw, text, x, y, scale, color, shadow_color=None):
    GLYPHS = {
        'S': [" ### ","#    ","#    "," ### ","    #","    #"," ### "],
        'C': [" ### ","#    ","#    ","#    ","#    ","#    "," ### "],
        'R': ["#### ","#   #","#   #","#### ","#  # ","#   #","#   #"],
        'A': [" ### ","#   #","#   #","#####","#   #","#   #","#   #"],
        'P': ["#### ","#   #","#   #","#### ","#    ","#    ","#    "],
        'W': ["#   #","#   #","#   #","# # #","# # #","## ##","#   #"],
        'I': ["#####","  #  ","  #  ","  #  ","  #  ","  #  ","#####"],
        'G': [" ### ","#    ","#    ","# ###","#   #","#   #"," ### "],
        'H': ["#   #","#   #","#   #","#####","#   #","#   #","#   #"],
        'T': ["#####","  #  ","  #  ","  #  ","  #  ","  #  ","  #  "],
        'E': ["#####","#    ","#    ","#### ","#    ","#    ","#####"],
        'V': ["#   #","#   #","#   #","#   #"," # # "," # # ","  #  "],
        'Y': ["#   #","#   #"," # # ","  #  ","  #  ","  #  ","  #  "],
        'O': [" ### ","#   #","#   #","#   #","#   #","#   #"," ### "],
        'N': ["#   #","##  #","##  #","# # #","#  ##","#  ##","#   #"],
        'D': ["#### ","#   #","#   #","#   #","#   #","#   #","#### "],
        'F': ["#####","#    ","#    ","#### ","#    ","#    ","#    "],
        'L': ["#    ","#    ","#    ","#    ","#    ","#    ","#####"],
        ' ': ["     ","     ","     ","     ","     ","     ","     "],
    }
    cursor_x = x
    for char in text.upper():
        glyph = GLYPHS.get(char, GLYPHS[' '])
        for row_idx, row in enumerate(glyph):
            for col_idx, pixel in enumerate(row):
                if pixel == '#':
                    px = cursor_x + col_idx * scale
                    py = y + row_idx * scale
                    if shadow_color:
                        draw.rectangle([px + scale, py + scale, px + scale * 2 - 1, py + scale * 2 - 1], fill=shadow_color)
                    draw.rectangle([px, py, px + scale - 1, py + scale - 1], fill=color)
        cursor_x += (len(glyph[0]) + 1) * scale
    return cursor_x - x


def measure_text(text, scale):
    return len(text) * 6 * scale


def render_frame(frame_num, bg):
    t = frame_num / TOTAL_FRAMES

    img = bg.copy().convert('RGBA')

    # Darken top for text readability
    overlay = Image.new('RGBA', (WIDTH, HEIGHT), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for y_pos in range(HEIGHT // 3):
        alpha = int(100 * (1.0 - y_pos / (HEIGHT // 3)))
        od.line([(0, y_pos), (WIDTH, y_pos)], fill=(0, 0, 0, alpha))
    img = Image.alpha_composite(img, overlay)

    # Composite real game sprite (idle animation)
    if DOG_FRAMES:
        dog_idx = int((frame_num / 10) % len(DOG_FRAMES))
        dog = DOG_FRAMES[dog_idx]
        # Crop to actual pixels, then scale up with nearest neighbor
        bbox = dog.getbbox()
        if bbox:
            cropped = dog.crop(bbox)
            dog_scale = 6
            dog_big = cropped.resize((cropped.width * dog_scale, cropped.height * dog_scale), Image.NEAREST)
            dog_x = (WIDTH - dog_big.width) // 2
            dog_y = HEIGHT - dog_big.height - 100
            img.paste(dog_big, (dog_x, dog_y), dog_big)

    draw = ImageDraw.Draw(img)

    # Title animation
    title = "SCRAPWRIGHT"
    title_scale = 12
    title_width = measure_text(title, title_scale)
    title_x = (WIDTH - title_width) // 2
    title_y = 140

    if t < 0.15:
        progress = t / 0.15
        ease = 1.0 - (1.0 - progress) ** 3
        title_y_offset = int(-300 * (1.0 - ease))
        title_alpha = progress
    elif t < 0.25:
        bounce_t = (t - 0.15) / 0.1
        title_y_offset = int(-15 * math.sin(bounce_t * math.pi))
        title_alpha = 1.0
    else:
        title_y_offset = 0
        title_alpha = 1.0

    if t > 0.85:
        title_alpha = 1.0 - (t - 0.85) / 0.15

    if title_alpha > 0:
        actual_y = title_y + title_y_offset
        glow = 0.5 + 0.5 * math.sin(t * math.pi * 4)
        r_val = int(GOLD[0] + (BRIGHT_GOLD[0] - GOLD[0]) * glow * 0.3)
        g_val = int(GOLD[1] + (BRIGHT_GOLD[1] - GOLD[1]) * glow * 0.3)
        b_val = int(GOLD[2] + (BRIGHT_GOLD[2] - GOLD[2]) * glow * 0.3)
        title_color = (min(r_val, 255), min(g_val, 255), min(b_val, 255))
        draw_pixel_text(draw, title, title_x, actual_y, title_scale, title_color, shadow_color=(20, 15, 5))

    # Subtitle
    subtitle = "EVERY SCRAP TELLS A STORY"
    sub_scale = 4
    sub_width = measure_text(subtitle, sub_scale)
    sub_x = (WIDTH - sub_width) // 2
    sub_y = title_y + 7 * title_scale + 50

    if t > 0.3 and title_alpha > 0:
        sub_progress = min((t - 0.3) / 0.2, 1.0)
        sub_alpha = sub_progress * title_alpha
        if sub_alpha > 0:
            sc = (int(180 * sub_alpha), int(200 * sub_alpha), int(210 * sub_alpha))
            draw_pixel_text(draw, subtitle, sub_x, sub_y + title_y_offset, sub_scale, sc, shadow_color=(10, 10, 10))

    # Floating particles
    random.seed(42)
    particle_layer = Image.new('RGBA', (WIDTH, HEIGHT), (0, 0, 0, 0))
    pd = ImageDraw.Draw(particle_layer)
    for i in range(30):
        px_base = random.randint(0, WIDTH)
        py_base = random.randint(0, HEIGHT)
        speed = random.uniform(0.3, 1.0)
        size = random.randint(2, 5)
        px = px_base + int(math.sin(t * math.pi * 2 + i) * 20)
        py = (py_base - int(t * 200 * speed)) % HEIGHT
        sparkle = abs(math.sin(t * math.pi * 3 + i * 0.7))
        if sparkle > 0.5 and title_alpha > 0:
            p_alpha = int(180 * sparkle * title_alpha)
            p_color = (*CYAN, p_alpha) if i % 3 == 0 else (*GOLD, p_alpha)
            pd.rectangle([px, py, px + size, py + size], fill=p_color)
    img = Image.alpha_composite(img, particle_layer)

    return img.convert('RGB')


def main():
    print("=== Rendering Scrapwright Title Card ===")

    # Find background
    bg_path = None
    for candidate in BG_CANDIDATES:
        if os.path.exists(candidate):
            bg_path = candidate
            break

    if bg_path:
        bg = Image.open(bg_path).convert('RGBA')
        if bg.size != (WIDTH, HEIGHT):
            bg = bg.resize((WIDTH, HEIGHT), Image.NEAREST)
        print(f"Background: {bg_path}")
    else:
        # Dark gradient fallback
        bg = Image.new('RGBA', (WIDTH, HEIGHT), (15, 10, 25, 255))
        d = ImageDraw.Draw(bg)
        for y in range(HEIGHT):
            t = y / HEIGHT
            d.line([(0, y), (WIDTH, y)], fill=(int(15 + 20 * t), int(10 + 10 * t), int(25 + 15 * t), 255))
        print("Using gradient fallback (no background found)")

    print(f"Dog frames: {len(DOG_FRAMES)}")
    print(f"Rendering {TOTAL_FRAMES} frames...")

    for frame_num in range(TOTAL_FRAMES):
        img = render_frame(frame_num, bg)
        frame_path = os.path.join(FRAMES_DIR, f"frame_{frame_num:04d}.png")
        img.save(frame_path)
        if frame_num % 30 == 0:
            print(f"  Frame {frame_num}/{TOTAL_FRAMES}")

    print("Encoding video...")
    output_path = os.path.join(OUTPUT_DIR, "title_card.mp4")
    subprocess.run([
        "ffmpeg", "-y",
        "-framerate", str(FPS),
        "-i", os.path.join(FRAMES_DIR, "frame_%04d.png"),
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-preset", "slow", "-crf", "18",
        output_path
    ], check=True, capture_output=True)

    for f in os.listdir(FRAMES_DIR):
        os.remove(os.path.join(FRAMES_DIR, f))
    os.rmdir(FRAMES_DIR)

    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"\nDone! Title card: {output_path} ({size_mb:.1f} MB)")


if __name__ == "__main__":
    main()
