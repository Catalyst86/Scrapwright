import requests, base64, os, time, urllib3
from PIL import Image
import io

# Disable SSL warnings for retries
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
HEADERS = {
    'Authorization': f'Bearer {API_KEY}',
    'Content-Type': 'application/json'
}
BASE_URL = 'https://api.pixellab.ai/v2'
SPRITES_DIR = r'C:\Users\danie\Desktop\roguelite\assets\sprites\enemies'
ANIM_DIR = r'C:\Users\danie\Desktop\roguelite\assets\sprites\animations'

os.makedirs(ANIM_DIR, exist_ok=True)

ENEMIES = [
    ("fungal_titan", "slamming fists creating shockwave"),
    ("magma_imp", "throwing fireball"),
    ("lava_lobber", "lobbing molten rock"),
    ("obsidian_golem", "crushing punch downward"),
    ("molten_wyrm", "breathing fire stream"),
    ("ember_drake", "flame breath attack"),
    ("frost_sprite", "casting ice shard spell"),
    ("ice_archer", "shooting ice arrow"),
    ("frost_warden", "swinging ice blade"),
    ("glacial_hulk", "ground pound ice slam"),
    ("crystal_bat", "sonic screech attack"),
    ("crystal_colossus", "crystal beam blast"),
]

def load_sprite_b64(name):
    path = os.path.join(SPRITES_DIR, f'enemy_{name}.png')
    img = Image.open(path).convert('RGBA')
    w, h = img.size
    if w > 256 or h > 256:
        ratio = min(256 / w, 256 / h)
        new_w, new_h = int(w * ratio), int(h * ratio)
        img = img.resize((new_w, new_h), Image.NEAREST)
        print(f"  Resized {w}x{h} -> {img.size[0]}x{img.size[1]}")
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

def call_api(payload, max_retries=3):
    """Call API with retry on 429 and timeouts. Uses 600s timeout."""
    for attempt in range(max_retries):
        t0 = time.time()
        try:
            # Use a session with longer timeouts
            sess = requests.Session()
            resp = sess.post(
                f'{BASE_URL}/animate-with-text-v3',
                headers=HEADERS,
                json=payload,
                timeout=(30, 540)  # 30s connect, 540s read
            )
            elapsed = time.time() - t0

            if resp.status_code == 429:
                wait = 60 * (attempt + 1)
                print(f"  Rate limited (attempt {attempt+1}/{max_retries}), waiting {wait}s...")
                time.sleep(wait)
                continue

            return resp, elapsed

        except (requests.exceptions.Timeout, requests.exceptions.ConnectionError) as e:
            elapsed = time.time() - t0
            print(f"  {type(e).__name__} after {elapsed:.0f}s (attempt {attempt+1}/{max_retries})")
            if attempt < max_retries - 1:
                wait = 60
                print(f"  Waiting {wait}s before retry...")
                time.sleep(wait)
                continue
            else:
                return None, elapsed

    return None, 0

total = len(ENEMIES)
success = 0
fail = 0

for idx, (name, action) in enumerate(ENEMIES, 1):
    out_path = os.path.join(ANIM_DIR, f'enemy_{name}_attack_sheet.png')

    if os.path.exists(out_path):
        print(f"[{idx}/{total}] enemy_{name} -- ALREADY EXISTS, skipping")
        success += 1
        continue

    print(f"\n[{idx}/{total}] enemy_{name} -- \"{action}\"")

    sprite_path = os.path.join(SPRITES_DIR, f'enemy_{name}.png')
    if not os.path.exists(sprite_path):
        print(f"  ERROR: Sprite not found")
        fail += 1
        continue

    try:
        sprite_b64, (fw, fh) = load_sprite_b64(name)
        print(f"  Sprite: {fw}x{fh}")
    except Exception as e:
        print(f"  ERROR loading sprite: {e}")
        fail += 1
        continue

    payload = {
        "first_frame": {"base64": sprite_b64},
        "action": action,
        "frame_count": 8
    }

    print(f"  Calling API (up to 540s read timeout)...")
    resp, elapsed = call_api(payload)

    if resp is None:
        print(f"  ERROR: All retries failed")
        fail += 1
        continue

    print(f"  HTTP {resp.status_code} ({elapsed:.1f}s)")

    if resp.status_code != 200:
        print(f"  ERROR: {resp.text[:300]}")
        fail += 1
        continue

    try:
        data = resp.json()
    except Exception as e:
        print(f"  ERROR parsing JSON: {e}")
        fail += 1
        continue

    if 'images' not in data:
        print(f"  ERROR: No 'images'. Keys: {list(data.keys())}. Detail: {str(data)[:200]}")
        fail += 1
        continue

    frames = [img['base64'] for img in data['images']]
    print(f"  Got {len(frames)} frames")

    make_spritesheet(frames, (fw, fh), out_path)
    print(f"  SAVED: {out_path}")
    success += 1

    # Wait between requests
    if idx < total:
        print(f"  Waiting 15s...")
        time.sleep(15)

print(f"\n{'='*50}")
print(f"COMPLETE: {success} succeeded, {fail} failed out of {total}")
