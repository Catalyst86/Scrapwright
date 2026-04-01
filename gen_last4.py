import requests, base64, os, time, sys
from PIL import Image
import io

sys.stdout.reconfigure(line_buffering=True)

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
HEADERS = {
    'Authorization': f'Bearer {API_KEY}',
    'Content-Type': 'application/json'
}
BASE_URL = 'https://api.pixellab.ai/v2'
SPRITES_DIR = r'C:\Users\danie\Desktop\roguelite\assets\sprites\enemies'
ANIM_DIR = r'C:\Users\danie\Desktop\roguelite\assets\sprites\animations'

ENEMIES = [
    ("abyssal_knight", "sword slash"),
    ("the_devourer", "bite attack"),
    ("the_architect", "energy blast"),
    ("scrap_king", "throwing projectiles"),
]

def load_sprite_b64(name):
    path = os.path.join(SPRITES_DIR, f'enemy_{name}.png')
    img = Image.open(path).convert('RGBA')
    w, h = img.size
    if w > 256 or h > 256:
        ratio = min(256 / w, 256 / h)
        new_w, new_h = int(w * ratio), int(h * ratio)
        img = img.resize((new_w, new_h), Image.NEAREST)
        print(f"  Resized {w}x{h} -> {img.size[0]}x{img.size[1]}", flush=True)
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode(), img.size

def make_spritesheet(frames_b64, frame_size, out_path):
    fw, fh = frame_size
    n = len(frames_b64)
    sheet = Image.new('RGBA', (fw * n, fh), (0, 0, 0, 0))
    for i, fb64 in enumerate(frames_b64):
        frame_img = Image.open(io.BytesIO(base64.b64decode(fb64))).convert('RGBA')
        if frame_img.size != (fw, fh):
            frame_img = frame_img.resize((fw, fh), Image.NEAREST)
        sheet.paste(frame_img, (i * fw, 0))
    sheet.save(out_path)

total = len(ENEMIES)
success = 0

for idx, (name, action) in enumerate(ENEMIES, 1):
    out_path = os.path.join(ANIM_DIR, f'enemy_{name}_attack_sheet.png')
    if os.path.exists(out_path):
        print(f"[{idx}/{total}] enemy_{name} -- ALREADY EXISTS", flush=True)
        success += 1
        continue

    print(f"[{idx}/{total}] enemy_{name} -- \"{action}\"", flush=True)
    sprite_b64, (fw, fh) = load_sprite_b64(name)
    print(f"  Sprite: {fw}x{fh}", flush=True)

    payload = {
        "first_frame": {"base64": sprite_b64},
        "action": action,
        "frame_count": 8
    }

    for attempt in range(2):
        print(f"  Attempt {attempt+1}/2 (300s timeout)...", flush=True)
        try:
            t0 = time.time()
            resp = requests.post(
                f'{BASE_URL}/animate-with-text-v3',
                headers=HEADERS,
                json=payload,
                timeout=300
            )
            elapsed = time.time() - t0
            print(f"  HTTP {resp.status_code} ({elapsed:.1f}s)", flush=True)

            if resp.status_code == 429:
                print(f"  Rate limited, waiting 60s...", flush=True)
                time.sleep(60)
                continue

            if resp.status_code == 200:
                data = resp.json()
                if 'images' in data:
                    frames = [img['base64'] for img in data['images']]
                    print(f"  Got {len(frames)} frames", flush=True)
                    make_spritesheet(frames, (fw, fh), out_path)
                    print(f"  SAVED: enemy_{name}_attack_sheet.png", flush=True)
                    success += 1
                    time.sleep(15)
                    break
                else:
                    print(f"  No images: {str(data)[:200]}", flush=True)
            else:
                print(f"  ERROR: {resp.text[:200]}", flush=True)
            break
        except requests.exceptions.Timeout:
            print(f"  Timeout after 300s", flush=True)
            time.sleep(15)
        except Exception as e:
            print(f"  ERROR: {e}", flush=True)
            break

print(f"\nDone: {success}/{total} succeeded", flush=True)
