"""
Generate reference images for each Kling 3.0 scene via PixelLab API.
These serve as start frames for image-to-video generation.
Output: scrapwright_intro/kling_refs/scene_N.png
"""
import requests, base64, os, time

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
BASE_URL = 'https://api.pixellab.ai/v1'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'kling_refs')
os.makedirs(OUT, exist_ok=True)

def gen(name, desc, w=128, h=72, no_bg=False, retries=2):
    path = os.path.join(OUT, name)
    if os.path.exists(path):
        print(f'SKIP {name}')
        return True
    for attempt in range(retries + 1):
        print(f'GEN  {name} (attempt {attempt+1})...', end=' ', flush=True)
        try:
            r = requests.post(f'{BASE_URL}/generate-image-pixflux', headers=HEADERS, json={
                'description': desc,
                'image_size': {'width': w, 'height': h},
                'outline': 'single color black outline',
                'shading': 'medium shading',
                'detail': 'medium detail',
                'no_background': no_bg
            }, timeout=180)
            d = r.json()
            if 'image' in d:
                with open(path, 'wb') as f:
                    f.write(base64.b64decode(d['image']['base64']))
                print('OK')
                return True
            else:
                print(f'ERR: {str(d)[:80]}')
        except Exception as e:
            print(f'ERR: {e}')
        if attempt < retries:
            time.sleep(5)
    return False

# === Character reference (standalone, for Kling character consistency) ===
print('=== Character Reference ===')
gen('dog_reference.png',
    'small cute golden puppy dog character with big dark eyes facing the camera standing on flat ground pixel art game character 16-bit style',
    w=128, h=128, no_bg=True)

# === Scene reference images (16:9, used as Kling start frames) ===
print('\n=== Scene 1: The Junkyard ===')
gen('scene1_start.png',
    'small golden puppy dog walking right through a dark steampunk junkyard wasteland with rusty scrap metal piles broken gears and pipes dark purple moody sky lonely atmosphere pixel art 16-bit game scene',
    w=128, h=72)

gen('scene1_end.png',
    'small golden puppy dog in the center of a dark steampunk junkyard with rusty metal everywhere dark moody sky the dog looks small and alone pixel art 16-bit game scene',
    w=128, h=72)

print('\n=== Scene 2: Kicked Away ===')
gen('scene2_start.png',
    'small golden puppy dog standing in a junkyard looking up at a large dark boot shadow looming above pixel art 16-bit game scene dark moody atmosphere',
    w=128, h=72)

gen('scene2_end.png',
    'small golden puppy dog cowering and flinching in a junkyard with a kicked tin can on the ground nearby the dog looks scared and small pixel art 16-bit game scene',
    w=128, h=72)

print('\n=== Scene 3: Rock Bottom ===')
gen('scene3_start.png',
    'small golden puppy dog sitting alone in the center of a very dark junkyard at night looking sad and defeated dim moonlight heavy shadows lonely desolate atmosphere pixel art 16-bit game scene',
    w=128, h=72)

print('\n=== Scene 4: The Rumble ===')
gen('scene4_start.png',
    'small golden puppy dog standing in a junkyard with dark red glowing sky the ground has cracks orange glow from below earthquake atmosphere debris falling pixel art 16-bit game scene',
    w=128, h=72)

gen('scene4_end.png',
    'junkyard ground cracking open with red orange lava glow erupting from cracks debris and rocks flying into the dark red sky apocalyptic earthquake pixel art 16-bit game scene',
    w=128, h=72)

print('\n=== Scene 5: Cataclysm ===')
gen('scene5_start.png',
    'massive apocalyptic explosion erupting from junkyard ground lava and debris flying upward fire and destruction dark red sky a tiny glowing cyan gold metal shard falls through the air pixel art 16-bit game scene',
    w=128, h=72)

print('\n=== Scene 6: The Artifact ===')
gen('scene6_start.png',
    'small golden puppy dog cautiously approaching a glowing cyan and gold magical metal shard on the ground in a dark junkyard at night the shard emits magical sparkles pixel art 16-bit game scene',
    w=128, h=72)

gen('scene6_flash.png',
    'bright white and cyan magical energy explosion flash expanding outward from center of a dark junkyard a small golden puppy dog is blown back by the force magical sparkles everywhere pixel art 16-bit game scene',
    w=128, h=72)

print('\n=== Scene 7: Hero Awakens ===')
gen('scene7_start.png',
    'dark red apocalyptic sky with fires burning in background dark silhouettes of people running in panic a small golden puppy dog stands firm in the center foreground with a glowing cyan gold artifact at its feet heroic pose pixel art 16-bit game scene',
    w=128, h=72)

gen('scene7_end.png',
    'close up of a determined small golden puppy dog face with glowing cyan and gold light illuminating it from below heroic expression dark red sky background pixel art 16-bit game scene',
    w=128, h=72)

print('\n=== All reference images generated! ===')
print(f'Output directory: {OUT}')
print(f'\nUpload these as start/end frames in Kling 3.0 image-to-video mode.')
