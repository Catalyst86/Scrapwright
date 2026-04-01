"""Fix failed UI sprites - regenerate at 32x32+ minimum then crop/resize as needed."""

import requests, base64, os
from PIL import Image
import io

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
BASE_URL = 'https://api.pixellab.ai/v1'
UI_DIR = r'C:\Users\danie\Desktop\roguelite\assets\sprites\ui'

STYLE_PREFIX = "steampunk pixel art, brass copper rivets gears, dark warm tones, chunky pixel style, game UI element"

def gen(name, desc, w=32, h=32, no_bg=True, target_w=None, target_h=None):
    out = os.path.join(UI_DIR, name)
    if os.path.exists(out):
        print(f'SKIP {name}')
        return

    # Ensure minimum 32x32 for API
    api_w = max(32, w)
    api_h = max(32, h)
    full_desc = f"{STYLE_PREFIX}, {desc}"
    print(f'Generating {name} ({api_w}x{api_h})...')

    try:
        r = requests.post(f'{BASE_URL}/generate-image-pixflux', headers=HEADERS, json={
            'description': full_desc,
            'image_size': {'width': api_w, 'height': api_h},
            'outline': 'single color black outline',
            'shading': 'medium shading',
            'detail': 'medium detail',
            'no_background': no_bg
        }, timeout=120)
        d = r.json()
        if 'image' in d:
            img_data = base64.b64decode(d['image']['base64'])
            img = Image.open(io.BytesIO(img_data)).convert('RGBA')

            # Resize to target if specified
            tw = target_w or w
            th = target_h or h
            if (tw != api_w or th != api_h):
                img = img.resize((tw, th), Image.NEAREST)

            img.save(out)
            print(f'  OK {name} (final: {tw}x{th})')
        else:
            print(f'  ERR {name}: {str(d)[:120]}')
    except Exception as e:
        print(f'  ERR {name}: {e}')

# === Icons that failed (need 32x32 minimum) ===

# Generate at 32x32, will display at 32x32 in game (close enough to 24x24)
gen('icon_heart.png', 'glowing red crystal heart icon, steampunk brass frame around heart, health icon for game HUD', 32, 32)
gen('icon_shield.png', 'brass steampunk shield icon with gear emblem, defense icon', 32, 32)
gen('icon_anvil.png', 'steampunk anvil icon with small hammer, crafting icon, brass copper', 32, 32)
gen('icon_wrench.png', 'steampunk wrench tool icon, brass copper, upgrade icon', 32, 32)
gen('icon_bag.png', 'steampunk leather bag satchel icon, brass buckle, inventory bag icon', 32, 32)
gen('icon_clock.png', 'steampunk pocket watch clock icon, brass gears visible, timer icon', 32, 32)

# Perk icons at 32x32
gen('icon_perk_hp.png', 'red heart with plus sign health upgrade perk icon, steampunk brass frame', 32, 32)
gen('icon_perk_speed.png', 'blue lightning bolt speed icon, steampunk brass frame, fast movement perk', 32, 32)
gen('icon_perk_damage.png', 'orange flame sword damage icon, steampunk brass frame, attack power perk', 32, 32)
gen('icon_perk_defense.png', 'grey steel shield defense icon, steampunk brass frame, armor protection perk', 32, 32)

# Material icons at 32x32
gen('mat_icon_iron.png', 'iron scrap metal chunk icon, steampunk style, material icon', 32, 32)
gen('mat_icon_timber.png', 'wooden timber plank icon, steampunk style, material icon', 32, 32)
gen('mat_icon_fuel.png', 'fuel canister icon glowing orange, steampunk style, material icon', 32, 32)
gen('mat_icon_organic.png', 'green organic plant leaf material icon, steampunk style, material icon', 32, 32)
gen('mat_icon_stone.png', 'stone rock chunk icon, steampunk style, material icon', 32, 32)
gen('mat_icon_blueprint.png', 'blueprint scroll paper icon, steampunk style, material icon', 32, 32)

# === Decorative elements that need wider aspect ratios ===

# Bars - generate at 96x32 then crop to just the bar portion
gen('bar_fill_hp.png', 'glowing green liquid health bar fill, bubbling potion fluid inside glass tube, horizontal bar, steampunk gauge', 96, 32, no_bg=False, target_w=88, target_h=14)
gen('bar_frame_xp.png', 'thin horizontal experience bar frame with copper border, small gear on left end, steampunk gauge bar', 96, 32, target_w=96, target_h=16)

# Horizontal decorative elements - generate at wider sizes
gen('divider_horizontal.png', 'horizontal ornate steampunk divider line with gear in center, brass copper, decorative separator bar', 128, 32, target_w=128, target_h=12)
gen('pipe_horizontal.png', 'horizontal copper steam pipe with rivets and joints, steampunk industrial, side view pipe', 128, 32, target_w=128, target_h=12)

# Corner brackets at 32x32
gen('corner_bracket_tl.png', 'top-left ornate corner bracket decoration, brass copper, steampunk, L-shaped with gear accent', 32, 32)
gen('corner_bracket_tr.png', 'top-right ornate corner bracket decoration, brass copper, steampunk, reversed L-shape with gear accent', 32, 32)
gen('corner_bracket_bl.png', 'bottom-left ornate corner bracket decoration, brass copper, steampunk, inverted L-shape with gear', 32, 32)
gen('corner_bracket_br.png', 'bottom-right ornate corner bracket decoration, brass copper, reversed inverted L-shape with gear', 32, 32)

# Gear small at 32x32
gen('gear_small.png', 'small brass gear cog wheel with teeth, copper metallic, steampunk industrial, single gear front view', 32, 32)

# Particles at 32x32 (will be scaled down in-game)
gen('particle_spark.png', 'tiny golden bright spark particle on black, glowing ember point, single bright spark, steampunk', 32, 32)
gen('particle_ember.png', 'small red orange glowing ember particle, tiny fire coal, single ember', 32, 32)
gen('particle_steam.png', 'small white steam puff cloud particle, tiny vapor wisp, steampunk steam', 32, 32)

# Rivet at 32x32 (will be scaled down)
gen('rivet.png', 'single large brass rivet bolt head centered, round metallic, steampunk, on dark background', 32, 32)

print('\n=== Fix generation complete! ===')

# List all files
files = sorted(os.listdir(UI_DIR))
png_files = [f for f in files if f.endswith('.png') and not f.endswith('.import')]
print(f'Total PNG files: {len(png_files)}')
for f in png_files:
    sz = os.path.getsize(os.path.join(UI_DIR, f))
    img = Image.open(os.path.join(UI_DIR, f))
    print(f'  {f} ({img.size[0]}x{img.size[1]}, {sz}b)')
