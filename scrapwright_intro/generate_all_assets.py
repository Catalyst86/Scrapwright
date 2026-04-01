"""
Generate ALL pixel art assets for Scrapwright intro video via PixelLab API.
Generates in batches with retries. All 64x64 for consistency.
"""
import requests, base64, os, time, sys
from PIL import Image
import io

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
BASE_URL = 'https://api.pixellab.ai/v1'
ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'assets')
os.makedirs(ASSETS, exist_ok=True)

def gen(name, desc, w=64, h=64, no_bg=True, retries=2):
    path = os.path.join(ASSETS, name)
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
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, 'wb') as f:
                    f.write(base64.b64decode(d['image']['base64']))
                print('OK')
                return True
            else:
                print(f'ERR: {str(d)[:80]}')
        except requests.exceptions.Timeout:
            print('TIMEOUT')
        except Exception as e:
            print(f'ERR: {e}')
        if attempt < retries:
            print(f'     Retrying in 5s...')
            time.sleep(5)
    return False


# ============================================================
# BATCH 1: BACKGROUNDS (128x72, will be upscaled to 384x216)
# ============================================================
print('\n=== BATCH 1: Backgrounds ===')

gen('bg_junkyard_1.png',
    'pixel art junkyard wasteland scene with piles of rusty scrap metal broken gears and pipes dark moody purple sky brown and grey tones steampunk industrial landscape wide view',
    w=128, h=72, no_bg=False)

gen('bg_junkyard_2.png',
    'pixel art junkyard scene different angle with rusty metal heaps broken machinery dark cloudy sky brown rust colors desolate steampunk landscape',
    w=128, h=72, no_bg=False)

gen('bg_junkyard_night.png',
    'pixel art junkyard at night very dark and moody with dim moonlight shadows and silhouettes of scrap piles lonely desolate atmosphere',
    w=128, h=72, no_bg=False)

gen('bg_red_sky.png',
    'pixel art junkyard with ominous red orange glowing sky cracks in ground apocalyptic earthquake scene dark steampunk wasteland fire glow from below',
    w=128, h=72, no_bg=False)

gen('bg_catastrophe.png',
    'pixel art apocalyptic scene dark red sky fire and explosions in background debris falling destroyed buildings silhouettes panic chaos wide landscape',
    w=128, h=72, no_bg=False)

# ============================================================
# BATCH 2: CHARACTERS & SILHOUETTES
# ============================================================
print('\n=== BATCH 2: Characters ===')

# Running person silhouettes - 4 different poses
gen('sil_run_1.png',
    'solid black silhouette of person running left leg forward right arm forward side view pixel art simple dark figure',
    w=48, h=64, no_bg=True)

gen('sil_run_2.png',
    'solid black silhouette of person running mid stride both legs apart side view pixel art simple dark figure',
    w=48, h=64, no_bg=True)

gen('sil_run_3.png',
    'solid black silhouette of person running right leg forward left arm forward side view pixel art simple dark figure',
    w=48, h=64, no_bg=True)

gen('sil_run_4.png',
    'solid black silhouette of person running legs together jumping stride side view pixel art simple dark figure',
    w=48, h=64, no_bg=True)

# Boot for kicking scene - multiple poses
gen('boot_wind_up.png',
    'large dark boot side view pulled back winding up for a kick pixel art simple dark silhouette',
    w=64, h=64, no_bg=True)

gen('boot_kick.png',
    'large dark boot side view extended forward kicking motion pixel art simple dark silhouette',
    w=64, h=64, no_bg=True)

gen('boot_follow_through.png',
    'large dark boot side view follow through after kick angled up pixel art simple dark silhouette',
    w=64, h=64, no_bg=True)

# ============================================================
# BATCH 3: PROPS & OBJECTS
# ============================================================
print('\n=== BATCH 3: Props ===')

gen('tin_can.png',
    'small rusty dented tin can pixel art simple metal can food container',
    w=32, h=32, no_bg=True)

gen('artifact_glow.png',
    'small jagged glowing metal shard with cyan and gold magical energy aura sparkles pixel art enchanted artifact',
    w=48, h=48, no_bg=True)

gen('artifact_large.png',
    'detailed jagged piece of glowing scrap metal with bright cyan and gold magic aura energy sparkles and runes pixel art magical artifact',
    w=64, h=64, no_bg=True)

gen('ground_crack_1.png',
    'dark crack in stone ground jagged fracture line spreading pixel art dark crack pattern on ground',
    w=96, h=48, no_bg=True)

gen('ground_crack_2.png',
    'wider dark crack in ground with branching fractures earthquake damage pixel art crack pattern',
    w=96, h=48, no_bg=True)

# ============================================================
# BATCH 4: DEBRIS & PARTICLES
# ============================================================
print('\n=== BATCH 4: Debris ===')

gen('debris_rock_1.png',
    'small rock chunk debris piece flying pixel art simple grey brown stone',
    w=32, h=32, no_bg=True)

gen('debris_rock_2.png',
    'small rubble debris chunk pixel art simple grey stone piece',
    w=32, h=32, no_bg=True)

gen('debris_metal.png',
    'small twisted metal scrap debris piece flying pixel art rusty metal chunk',
    w=32, h=32, no_bg=True)

gen('ember_particle.png',
    'tiny glowing orange ember spark particle pixel art simple fire spark',
    w=32, h=32, no_bg=True)

gen('magic_spark.png',
    'tiny glowing cyan magic sparkle particle with small glow pixel art magical spark',
    w=32, h=32, no_bg=True)

# ============================================================
# BATCH 5: EFFECTS
# ============================================================
print('\n=== BATCH 5: Effects ===')

gen('magic_burst.png',
    'white and cyan magic energy explosion burst expanding ring of light bright flash pixel art magical explosion effect',
    w=96, h=96, no_bg=True)

gen('magic_burst_large.png',
    'large white and cyan and gold magic energy shockwave expanding outward bright magical explosion pixel art effect',
    w=128, h=128, no_bg=True)

gen('dust_cloud.png',
    'small brown dust cloud puff dirt cloud pixel art simple particle effect',
    w=32, h=32, no_bg=True)

# ============================================================
# BATCH 6: JUNKYARD PROPS (for richer backgrounds)
# ============================================================
print('\n=== BATCH 6: Junkyard detail props ===')

gen('junk_barrel.png',
    'rusty metal barrel with dents steampunk industrial barrel pixel art prop',
    w=32, h=48, no_bg=True)

gen('junk_pipe.png',
    'rusty industrial pipe section horizontal with steam steampunk pixel art prop',
    w=64, h=32, no_bg=True)

gen('junk_gear.png',
    'large rusty metal gear cog steampunk industrial pixel art prop',
    w=48, h=48, no_bg=True)

gen('junk_pile.png',
    'pile of scrap metal junk heap rusty steampunk industrial debris pixel art',
    w=64, h=48, no_bg=True)

gen('junk_crane.png',
    'broken rusty crane arm silhouette dark steampunk industrial pixel art background element',
    w=64, h=96, no_bg=True)

print('\n=== All asset generation attempts complete! ===')

# Count results
total = 0
ok = 0
for root, dirs, files in os.walk(ASSETS):
    for f in files:
        if f.endswith('.png') and not f.startswith('bg_junkyard_wide') and not f.startswith('bg_panic'):
            total += 1
            if os.path.getsize(os.path.join(root, f)) > 100:
                ok += 1
print(f'Assets: {ok}/{total} successfully generated')
print(f'Directory: {ASSETS}')
