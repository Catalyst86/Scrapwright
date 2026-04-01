"""
Generate east-facing walk/attack/die animation sheets for scrapyard enemies
using PixelLab animate-with-text-v3, then mirror for west-facing.

Existing south-facing sheets are used as reference (first frame).
"""

import requests, base64, os, sys, time
from PIL import Image
import io

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
H = {
    'Authorization': f'Bearer {API_KEY}',
    'Content-Type': 'application/json'
}
BASE_URL = 'https://api.pixellab.ai/v2'

SPRITES = r'C:\Users\danie\Desktop\Scrapwright Safe copy\assets\sprites'
ANIM_DIR = os.path.join(SPRITES, 'animations')

ENEMIES = {
    'rusher': {
        'desc': 'small goblin gremlin melee creature',
        'walk_action': 'running to the right, side view facing east',
        'attack_action': 'slashing claws attack to the right, side view facing east',
        'die_action': 'falling over dead to the right, side view facing east',
    },
    'shooter': {
        'desc': 'skeleton archer with bow',
        'walk_action': 'walking to the right carrying bow, side view facing east',
        'attack_action': 'drawing and shooting bow to the right, side view facing east',
        'die_action': 'collapsing dead bones scattering, side view facing east',
    },
    'tank': {
        'desc': 'large stone golem heavy creature',
        'walk_action': 'stomping slowly to the right, side view facing east',
        'attack_action': 'slamming fists down attacking to the right, side view facing east',
        'die_action': 'crumbling apart into rocks, side view facing east',
    },
    'flyer': {
        'desc': 'bat creature with wings',
        'walk_action': 'flying flapping wings to the right, side view facing east',
        'attack_action': 'diving swooping attack to the right, side view facing east',
        'die_action': 'falling from sky wings folding, side view facing east',
    },
    'exploder': {
        'desc': 'round bomb creature with lit fuse',
        'walk_action': 'bouncing rolling to the right, side view facing east',
        'attack_action': 'swelling up about to explode, side view facing east',
        'die_action': 'exploding into pieces, side view facing east',
    },
}

def img_to_b64(img):
    """Convert PIL Image to base64 string."""
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode()

def b64_to_img(b64_str):
    """Convert base64 string to PIL Image."""
    return Image.open(io.BytesIO(base64.b64decode(b64_str))).convert('RGBA')

def extract_first_frame(sheet_path, frame_size=64):
    """Extract first frame from a horizontal strip sheet."""
    sheet = Image.open(sheet_path).convert('RGBA')
    return sheet.crop((0, 0, frame_size, frame_size))

def make_sheet(frames):
    """Build horizontal strip from list of PIL Images."""
    if not frames:
        return None
    fw, fh = frames[0].size
    sheet = Image.new('RGBA', (fw * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        # Resize to match if needed
        if f.size != (fw, fh):
            f = f.resize((fw, fh), Image.NEAREST)
        sheet.paste(f, (i * fw, 0))
    return sheet

def mirror_sheet(sheet, frame_size=64):
    """Horizontally flip each frame in a sheet to create the opposite direction."""
    if not sheet:
        return None
    w, h = sheet.size
    n_frames = w // frame_size
    mirrored = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for i in range(n_frames):
        frame = sheet.crop((i * frame_size, 0, (i + 1) * frame_size, h))
        frame = frame.transpose(Image.FLIP_LEFT_RIGHT)
        mirrored.paste(frame, (i * frame_size, 0))
    return mirrored

def animate_v3(first_frame_img, action, frame_count=8, seed=None):
    """Call PixelLab animate-with-text-v3."""
    body = {
        "first_frame": {
            "type": "base64",
            "base64": img_to_b64(first_frame_img),
            "format": "png"
        },
        "action": action,
        "frame_count": frame_count,
        "no_background": True,
    }
    if seed is not None:
        body["seed"] = seed

    print(f"    Calling animate-with-text-v3: {action[:50]}...")
    for attempt in range(3):
        try:
            r = requests.post(f'{BASE_URL}/animate-with-text-v3', headers=H, json=body, timeout=180)
            break
        except requests.exceptions.ReadTimeout:
            print(f"    TIMEOUT (attempt {attempt+1}/3), retrying...")
            time.sleep(5)
    else:
        print(f"    FAILED: All 3 attempts timed out")
        return None

    if r.status_code != 200:
        print(f"    ERROR {r.status_code}: {r.text[:200]}")
        return None

    data = r.json()
    # v3 returns images in data field
    images = None
    if 'data' in data and 'images' in data['data']:
        images = data['data']['images']
    elif 'images' in data:
        images = data['images']
    elif 'data' in data and isinstance(data['data'], list):
        images = data['data']

    if not images:
        print(f"    ERROR: No images in response. Keys: {list(data.keys())}")
        if 'data' in data:
            print(f"    data keys: {list(data['data'].keys()) if isinstance(data['data'], dict) else type(data['data'])}")
        return None

    frames = []
    for img_data in images:
        if isinstance(img_data, dict):
            b64 = img_data.get('base64', img_data.get('image', ''))
        else:
            b64 = img_data
        if b64:
            frames.append(b64_to_img(b64))

    print(f"    Got {len(frames)} frames")
    return frames


def generate_east_sheets(enemy_type, enemy_info):
    """Generate east-facing walk, attack, die sheets for one enemy."""
    print(f"\n{'='*60}")
    print(f"Generating east-facing sheets for: {enemy_type}")
    print(f"{'='*60}")

    # Get first frame from existing south walk sheet as reference
    south_walk = os.path.join(ANIM_DIR, f'enemy_{enemy_type}_walk_sheet.png')
    if not os.path.exists(south_walk):
        print(f"  SKIP: No south walk sheet found")
        return False

    ref_frame = extract_first_frame(south_walk)

    anims = {
        'walk': {'action': enemy_info['walk_action'], 'frames': 8, 'seed': 42},
        'attack': {'action': enemy_info['attack_action'], 'frames': 8, 'seed': 43},
        'die': {'action': enemy_info['die_action'], 'frames': 6, 'seed': 44},
    }

    for anim_name, anim_info in anims.items():
        east_path = os.path.join(ANIM_DIR, f'enemy_{enemy_type}_{anim_name}_east_sheet.png')
        west_path = os.path.join(ANIM_DIR, f'enemy_{enemy_type}_{anim_name}_west_sheet.png')

        if os.path.exists(east_path) and os.path.exists(west_path):
            print(f"  SKIP {anim_name}: east + west sheets already exist")
            continue

        print(f"\n  Generating {anim_name} (east)...")
        frames = animate_v3(ref_frame, anim_info['action'], anim_info['frames'], anim_info['seed'])

        if not frames or len(frames) < 2:
            print(f"  FAILED: Not enough frames for {anim_name}")
            continue

        # Build east sheet
        east_sheet = make_sheet(frames)
        if east_sheet:
            east_sheet.save(east_path)
            print(f"  SAVED: {os.path.basename(east_path)} ({east_sheet.size[0]}x{east_sheet.size[1]}, {len(frames)} frames)")

            # Mirror for west
            west_sheet = mirror_sheet(east_sheet)
            if west_sheet:
                west_sheet.save(west_path)
                print(f"  SAVED: {os.path.basename(west_path)} (mirrored)")

        # Small delay between API calls
        time.sleep(1)

    return True


def rename_south_sheets():
    """Rename existing sheets to include _south_ suffix for consistency."""
    for enemy_type in ENEMIES:
        for anim in ['walk', 'attack', 'die']:
            old_path = os.path.join(ANIM_DIR, f'enemy_{enemy_type}_{anim}_sheet.png')
            new_path = os.path.join(ANIM_DIR, f'enemy_{enemy_type}_{anim}_south_sheet.png')
            if os.path.exists(old_path) and not os.path.exists(new_path):
                # Copy (don't rename) to keep backward compat
                img = Image.open(old_path)
                img.save(new_path)
                print(f"  Copied {os.path.basename(old_path)} -> {os.path.basename(new_path)}")


if __name__ == '__main__':
    print("PixelLab v3 Enemy Direction Generator")
    print("=" * 60)

    # Step 1: Copy existing sheets with _south_ suffix
    print("\nStep 1: Creating south-suffixed copies of existing sheets...")
    rename_south_sheets()

    # Step 2: Generate east + west for each enemy
    print("\nStep 2: Generating east/west animations...")
    for enemy_type, enemy_info in ENEMIES.items():
        generate_east_sheets(enemy_type, enemy_info)

    print("\n" + "=" * 60)
    print("DONE! All directional sheets generated.")
    print("Next: Update enemy_base.gd to load directional sheets.")
