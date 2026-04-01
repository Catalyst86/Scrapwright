"""Regenerate specific enemy animations with better prompts."""
import requests, base64, os, time
from PIL import Image
import io

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
H = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
BASE_URL = 'https://api.pixellab.ai/v2'
ANIM_DIR = r'C:\Users\danie\Desktop\Scrapwright Safe copy\assets\sprites\animations'

def img_to_b64(img):
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode()

def b64_to_img(b64_str):
    return Image.open(io.BytesIO(base64.b64decode(b64_str))).convert('RGBA')

def extract_first_frame(sheet_path, frame_size=64):
    sheet = Image.open(sheet_path).convert('RGBA')
    return sheet.crop((0, 0, frame_size, frame_size))

def make_sheet(frames):
    if not frames: return None
    fw, fh = frames[0].size
    sheet = Image.new('RGBA', (fw * len(frames), fh), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        if f.size != (fw, fh):
            f = f.resize((fw, fh), Image.NEAREST)
        sheet.paste(f, (i * fw, 0))
    return sheet

def mirror_sheet(sheet, frame_size=64):
    if not sheet: return None
    w, h = sheet.size
    n_frames = w // frame_size
    mirrored = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for i in range(n_frames):
        frame = sheet.crop((i * frame_size, 0, (i + 1) * frame_size, h))
        frame = frame.transpose(Image.FLIP_LEFT_RIGHT)
        mirrored.paste(frame, (i * frame_size, 0))
    return mirrored

def animate_v3(first_frame_img, action, frame_count=8, seed=None):
    body = {
        "first_frame": {"type": "base64", "base64": img_to_b64(first_frame_img), "format": "png"},
        "action": action,
        "frame_count": frame_count,
        "no_background": True,
    }
    if seed is not None:
        body["seed"] = seed

    print(f"  API call: {action[:60]}...")
    for attempt in range(3):
        try:
            r = requests.post(f'{BASE_URL}/animate-with-text-v3', headers=H, json=body, timeout=180)
            break
        except requests.exceptions.ReadTimeout:
            print(f"  TIMEOUT (attempt {attempt+1}/3)")
            time.sleep(5)
    else:
        print(f"  FAILED all attempts")
        return None

    if r.status_code != 200:
        print(f"  ERROR {r.status_code}: {r.text[:200]}")
        return None

    data = r.json()
    images = None
    if 'data' in data and 'images' in data['data']:
        images = data['data']['images']
    elif 'images' in data:
        images = data['images']
    elif 'data' in data and isinstance(data['data'], list):
        images = data['data']
    if not images:
        print(f"  ERROR: No images")
        return None

    frames = []
    for img_data in images:
        b64 = img_data.get('base64', img_data.get('image', '')) if isinstance(img_data, dict) else img_data
        if b64: frames.append(b64_to_img(b64))
    print(f"  Got {len(frames)} frames")
    return frames

def gen(enemy, anim, action, frame_count=8, seed=None):
    east_path = os.path.join(ANIM_DIR, f'enemy_{enemy}_{anim}_east_sheet.png')
    west_path = os.path.join(ANIM_DIR, f'enemy_{enemy}_{anim}_west_sheet.png')
    if os.path.exists(east_path):
        print(f"SKIP {enemy} {anim}: already exists")
        return

    # Use east walk sheet first frame as reference, fallback to south walk
    ref_path = os.path.join(ANIM_DIR, f'enemy_{enemy}_walk_east_sheet.png')
    if not os.path.exists(ref_path):
        ref_path = os.path.join(ANIM_DIR, f'enemy_{enemy}_walk_sheet.png')
    ref = extract_first_frame(ref_path)

    print(f"\n--- {enemy} {anim} ---")
    frames = animate_v3(ref, action, frame_count, seed)
    if not frames or len(frames) < 2:
        print(f"FAILED {enemy} {anim}")
        return

    east_sheet = make_sheet(frames)
    east_sheet.save(east_path)
    print(f"  SAVED {os.path.basename(east_path)} ({east_sheet.size[0]}x{east_sheet.size[1]})")

    west_sheet = mirror_sheet(east_sheet)
    west_sheet.save(west_path)
    print(f"  SAVED {os.path.basename(west_path)} (mirrored)")
    time.sleep(1)


# === FLYER: proper death animation ===
gen('flyer', 'die',
    'bat creature hit and crashing down to the ground, wings crumpling, tumbling and landing dead on the floor, side view facing right',
    frame_count=8, seed=55)

# === TANK: smooth walking ===
gen('tank', 'walk',
    'large stone golem walking steadily to the right with heavy footsteps, arms swinging, continuous smooth walk cycle, side view facing east',
    frame_count=8, seed=60)

# === TANK: proper death ===
gen('tank', 'die',
    'large stone golem cracking apart and crumbling into rubble pieces, chunks of rock breaking off and falling to the ground, collapsing dead, side view facing right',
    frame_count=8, seed=61)

# === EXPLODER: proper death ===
gen('exploder', 'die',
    'round bomb creature swelling up bright red then exploding violently into many pieces and smoke, big dramatic explosion with debris flying outward, side view',
    frame_count=8, seed=70)

print("\nDONE!")
