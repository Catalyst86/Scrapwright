"""
Generate missing puppy animations via PixelLab API.
Uses /animate-with-text with reference images for consistency.
Uses /rotate to create armor idle references from armor running frames.

Missing:
1. Armor idle (8 directions) — use armor run frame_000 as reference
2. Base jumping (8 directions) — use base run frame_000 as reference
3. Bandana jumping (8 directions) — use bandana run frame_000 as reference
4. Armor jumping (8 directions) — use armor run frame_000 as reference
"""

import requests, base64, os, time, sys
from PIL import Image
import io

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
HEADERS = {
    'Authorization': f'Bearer {API_KEY}',
    'Content-Type': 'application/json'
}
BASE_URL = 'https://api.pixellab.ai/v1'
PLAYER_DIR = r'C:\Users\danie\Desktop\roguelite\assets\sprites\player'

DIRS_8 = ['south', 'south-east', 'east', 'north-east', 'north', 'north-west', 'west', 'south-west']

# PixelLab direction mapping
PIXELLAB_DIRS = {
    'south': 'south',
    'south-east': 'south-east',
    'east': 'east',
    'north-east': 'north-east',
    'north': 'north',
    'north-west': 'north-west',
    'west': 'west',
    'south-west': 'south-west',
}


def img_to_b64(path, resize_to=None):
    """Load image, optionally resize, return base64 PNG string."""
    img = Image.open(path).convert('RGBA')
    if resize_to:
        img = img.resize((resize_to, resize_to), Image.NEAREST)
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode()


def b64_to_img(b64_str):
    """Decode base64 to PIL Image."""
    return Image.open(io.BytesIO(base64.b64decode(b64_str))).convert('RGBA')


def save_frames(frames, out_dir):
    """Save list of PIL Images as frame_000.png, frame_001.png, etc."""
    os.makedirs(out_dir, exist_ok=True)
    for i, img in enumerate(frames):
        img.save(os.path.join(out_dir, f'frame_{i:03d}.png'))


def check_balance():
    """Check remaining API balance."""
    r = requests.get(f'{BASE_URL}/balance', headers=HEADERS, timeout=30)
    data = r.json()
    print(f"API Balance: ${data.get('balance', '?')}")
    return float(data.get('balance', 0))


def animate_with_text(reference_path, description, action, output_size=92, guidance_scale=8):
    """
    Generate 4 animation frames using /animate-with-text.
    API only supports 64x64, so we downscale ref and upscale results.
    Returns list of 4 PIL Images at output_size, or None on failure.
    """
    ref_b64 = img_to_b64(reference_path, resize_to=64)

    body = {
        "description": description,
        "action": action,
        "reference_image": {"base64": ref_b64},
        "image_size": {"width": 64, "height": 64},
        "text_guidance_scale": 6,
        "image_guidance_scale": guidance_scale,
    }

    try:
        r = requests.post(f'{BASE_URL}/animate-with-text', headers=HEADERS, json=body, timeout=120)
        data = r.json()

        if 'images' in data:
            frames = [b64_to_img(img['base64']) for img in data['images']]
            # Upscale to target output size using nearest neighbor (pixel art)
            if output_size != 64:
                frames = [f.resize((output_size, output_size), Image.NEAREST) for f in frames]
            return frames
        elif 'image' in data:
            img = b64_to_img(data['image']['base64'])
            if output_size != 64:
                img = img.resize((output_size, output_size), Image.NEAREST)
            return [img]
        else:
            print(f"  API error: {str(data)[:120]}")
            return None
    except Exception as e:
        print(f"  Request failed: {e}")
        return None


def rotate_sprite(from_path, from_dir, to_dir, output_size=128):
    """
    Rotate a sprite from one direction to another using /rotate.
    API max is 200x200, so we use min(output_size, 200).
    Returns PIL Image at output_size or None.
    """
    api_size = min(output_size, 200)
    ref_b64 = img_to_b64(from_path, resize_to=api_size)

    body = {
        "from_image": {"base64": ref_b64},
        "image_size": {"width": api_size, "height": api_size},
        "from_direction": from_dir,
        "to_direction": to_dir,
        "image_guidance_scale": 10,
    }

    try:
        r = requests.post(f'{BASE_URL}/rotate', headers=HEADERS, json=body, timeout=120)
        data = r.json()

        if 'image' in data:
            img = b64_to_img(data['image']['base64'])
            if img.size[0] != output_size:
                img = img.resize((output_size, output_size), Image.NEAREST)
            return img
        else:
            print(f"  Rotate error: {str(data)[:120]}")
            return None
    except Exception as e:
        print(f"  Rotate failed: {e}")
        return None


# =====================================================================
# MAIN
# =====================================================================

print("=" * 60)
print("PixelLab Missing Animation Generator")
print("=" * 60)
balance = check_balance()
print()

generated = 0
failed = 0

# ─── 1. ARMOR IDLE (8 directions) ───────────────────────────
print(">>> ARMOR IDLE — Generating from armor run references")
for d in DIRS_8:
    out_dir = os.path.join(PLAYER_DIR, 'armor', 'idle', d)
    if os.path.exists(out_dir) and len(os.listdir(out_dir)) >= 4:
        print(f"  SKIP {d} (already exists)")
        continue

    # Use first frame of armor running in this direction as reference
    ref_path = os.path.join(PLAYER_DIR, 'armor', 'run', d, 'frame_000.png')
    if not os.path.exists(ref_path):
        print(f"  SKIP {d} (no reference)")
        failed += 1
        continue

    print(f"  Generating armor idle {d}...", end=" ", flush=True)
    frames = animate_with_text(
        ref_path,
        "adorable puppy with big eyes wearing armor, idle breathing animation, pixel art",
        "idle breathing",
        output_size=128,
        guidance_scale=10
    )

    if frames and len(frames) >= 4:
        save_frames(frames[:4], out_dir)
        print(f"OK ({len(frames)} frames)")
        generated += 1
    else:
        print("FAILED")
        failed += 1

    time.sleep(1)  # Rate limit

# ─── 2. BASE JUMPING (8 directions) ─────────────────────────
print()
print(">>> BASE JUMPING — Generating from base run references")
for d in DIRS_8:
    out_dir = os.path.join(PLAYER_DIR, 'base', 'jump', d)
    if os.path.exists(out_dir) and len(os.listdir(out_dir)) >= 4:
        print(f"  SKIP {d} (already exists)")
        continue

    ref_path = os.path.join(PLAYER_DIR, 'base', 'run', d, 'frame_000.png')
    if not os.path.exists(ref_path):
        print(f"  SKIP {d} (no reference)")
        failed += 1
        continue

    print(f"  Generating base jump {d}...", end=" ", flush=True)
    frames = animate_with_text(
        ref_path,
        "adorable puppy with big eyes, jumping up then landing, pixel art",
        "jumping up and landing",
        output_size=92,
        guidance_scale=10
    )

    if frames and len(frames) >= 4:
        save_frames(frames[:4], out_dir)
        print(f"OK ({len(frames)} frames)")
        generated += 1
    else:
        print("FAILED")
        failed += 1

    time.sleep(1)

# ─── 3. BANDANA JUMPING (8 directions) ──────────────────────
print()
print(">>> BANDANA JUMPING — Generating from bandana run references")
for d in DIRS_8:
    out_dir = os.path.join(PLAYER_DIR, 'bandana', 'jump', d)
    if os.path.exists(out_dir) and len(os.listdir(out_dir)) >= 4:
        print(f"  SKIP {d} (already exists)")
        continue

    ref_path = os.path.join(PLAYER_DIR, 'bandana', 'run', d, 'frame_000.png')
    if not os.path.exists(ref_path):
        print(f"  SKIP {d} (no reference)")
        failed += 1
        continue

    print(f"  Generating bandana jump {d}...", end=" ", flush=True)
    frames = animate_with_text(
        ref_path,
        "adorable puppy with big eyes wearing red bandana, jumping up then landing, pixel art",
        "jumping up and landing",
        output_size=128,
        guidance_scale=10
    )

    if frames and len(frames) >= 4:
        save_frames(frames[:4], out_dir)
        print(f"OK ({len(frames)} frames)")
        generated += 1
    else:
        print("FAILED")
        failed += 1

    time.sleep(1)

# ─── 4. ARMOR JUMPING (8 directions) ────────────────────────
print()
print(">>> ARMOR JUMPING — Generating from armor run references")
for d in DIRS_8:
    out_dir = os.path.join(PLAYER_DIR, 'armor', 'jump', d)
    if os.path.exists(out_dir) and len(os.listdir(out_dir)) >= 4:
        print(f"  SKIP {d} (already exists)")
        continue

    ref_path = os.path.join(PLAYER_DIR, 'armor', 'run', d, 'frame_000.png')
    if not os.path.exists(ref_path):
        print(f"  SKIP {d} (no reference)")
        failed += 1
        continue

    print(f"  Generating armor jump {d}...", end=" ", flush=True)
    frames = animate_with_text(
        ref_path,
        "adorable puppy with big eyes wearing armor, jumping up then landing, pixel art",
        "jumping up and landing",
        output_size=128,
        guidance_scale=10
    )

    if frames and len(frames) >= 4:
        save_frames(frames[:4], out_dir)
        print(f"OK ({len(frames)} frames)")
        generated += 1
    else:
        print("FAILED")
        failed += 1

    time.sleep(1)

# ─── SUMMARY ────────────────────────────────────────────────
print()
print("=" * 60)
print(f"Generated: {generated} animation sets")
print(f"Failed: {failed}")
print()

# Final inventory
for tier in ['base', 'bandana', 'armor']:
    tier_dir = os.path.join(PLAYER_DIR, tier)
    print(f"=== {tier.upper()} ===")
    if os.path.exists(tier_dir):
        for anim in sorted(os.listdir(tier_dir)):
            anim_path = os.path.join(tier_dir, anim)
            if os.path.isdir(anim_path):
                dirs = [d for d in os.listdir(anim_path) if os.path.isdir(os.path.join(anim_path, d))]
                if dirs:
                    sample_dir = os.path.join(anim_path, dirs[0])
                    frame_count = len([f for f in os.listdir(sample_dir) if f.endswith('.png')])
                    print(f"  {anim}: {len(dirs)} directions, {frame_count} frames")
    print()

check_balance()
print("Done!")
