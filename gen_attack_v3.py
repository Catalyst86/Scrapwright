import requests, base64, os, time
from PIL import Image
import io

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
    ("rusher", "lunging forward biting aggressively"),
    ("shooter", "drawing bow and shooting arrow"),
    ("tank", "smashing ground with fists"),
    ("flyer", "diving down swooping attack"),
    ("exploder", "swelling up and exploding"),
    ("spark_bug", "zapping with electric spark"),
    ("scrap_sentinel", "swinging metal arm attack"),
    ("junkyard_mech", "stomping and punching"),
    ("spore_walker", "releasing spore cloud"),
    ("fungal_brute", "charging forward headbutt"),
    ("mycelium_sniper", "shooting fungal projectile"),
    ("spore_mother", "summoning spore burst"),
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

def call_api_with_retry(payload, max_retries=10, initial_wait=30):
    """Call API with retry on 429 rate limit errors."""
    wait = initial_wait
    for attempt in range(max_retries):
        try:
            resp = requests.post(
                f'{BASE_URL}/animate-with-text-v3',
                headers=HEADERS,
                json=payload,
                timeout=120
            )
            if resp.status_code == 429:
                print(f"  Rate limited (attempt {attempt+1}/{max_retries}), waiting {wait}s...", flush=True)
                time.sleep(wait)
                wait = min(wait + 15, 120)
                continue
            return resp
        except requests.exceptions.Timeout:
            print(f"  Timeout (attempt {attempt+1}/{max_retries}), retrying...", flush=True)
            time.sleep(10)
            continue
    return None

total = len(ENEMIES)
success = 0
fail = 0

for idx, (name, action) in enumerate(ENEMIES, 1):
    print(f"\n[{idx}/{total}] enemy_{name} -- \"{action}\"", flush=True)

    sprite_path = os.path.join(SPRITES_DIR, f'enemy_{name}.png')
    if not os.path.exists(sprite_path):
        print(f"  ERROR: Sprite not found at {sprite_path}", flush=True)
        fail += 1
        continue

    try:
        sprite_b64, (fw, fh) = load_sprite_b64(name)
        print(f"  Sprite loaded: {fw}x{fh}", flush=True)
    except Exception as e:
        print(f"  ERROR loading sprite: {e}", flush=True)
        fail += 1
        continue

    payload = {
        "first_frame": {"base64": sprite_b64},
        "action": action,
        "frame_count": 8
    }

    print(f"  Calling API...", flush=True)
    t0 = time.time()
    try:
        resp = call_api_with_retry(payload)
        elapsed = time.time() - t0

        if resp is None:
            print(f"  ERROR: All retries exhausted ({elapsed:.1f}s)", flush=True)
            fail += 1
            continue

        print(f"  Response: HTTP {resp.status_code} ({elapsed:.1f}s)", flush=True)

        if resp.status_code != 200:
            print(f"  ERROR: {resp.text[:300]}", flush=True)
            fail += 1
            continue

        data = resp.json()

        if 'images' not in data:
            print(f"  ERROR: No 'images' key. Response: {str(data)[:300]}", flush=True)
            fail += 1
            continue

        frames = [img['base64'] for img in data['images']]
        print(f"  Got {len(frames)} frames", flush=True)

        out_path = os.path.join(ANIM_DIR, f'enemy_{name}_attack_sheet.png')
        make_spritesheet(frames, (fw, fh), out_path)
        print(f"  SAVED: {out_path}", flush=True)
        success += 1

    except Exception as e:
        print(f"  ERROR: {type(e).__name__}: {e}", flush=True)
        fail += 1

print(f"\n{'='*50}")
print(f"COMPLETE: {success} succeeded, {fail} failed out of {total}")
