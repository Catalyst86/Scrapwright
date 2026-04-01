"""
Generate unique steampunk pixel-art UI sprites via PixelLab API.
All sprites share a consistent steampunk/brass/copper aesthetic.
"""

import requests, base64, os, time, sys
from PIL import Image
import io

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
BASE_URL = 'https://api.pixellab.ai/v1'
UI_DIR = r'C:\Users\danie\Desktop\roguelite\assets\sprites\ui'

os.makedirs(UI_DIR, exist_ok=True)

STYLE_PREFIX = "steampunk pixel art, brass copper rivets gears, dark warm tones, chunky pixel style, game UI element"

def gen(name, desc, w=64, h=64):
    out = os.path.join(UI_DIR, name)
    if os.path.exists(out):
        print(f'SKIP {name}')
        return True

    full_desc = f"{STYLE_PREFIX}, {desc}"
    print(f'Generating {name} ({w}x{h})...')

    try:
        r = requests.post(f'{BASE_URL}/generate-image-pixflux', headers=HEADERS, json={
            'description': full_desc,
            'image_size': {'width': w, 'height': h},
            'outline': 'single color black outline',
            'shading': 'medium shading',
            'detail': 'medium detail',
            'no_background': True
        }, timeout=120)
        d = r.json()
        if 'image' in d:
            img_data = base64.b64decode(d['image']['base64'])
            open(out, 'wb').write(img_data)
            print(f'  OK {name}')
            return True
        else:
            print(f'  ERR {name}: {str(d)[:120]}')
            return False
    except Exception as e:
        print(f'  ERR {name}: {e}')
        return False

def gen_with_bg(name, desc, w=64, h=64):
    """Generate WITH background (for panels/frames that need filled areas)"""
    out = os.path.join(UI_DIR, name)
    if os.path.exists(out):
        print(f'SKIP {name}')
        return True

    full_desc = f"{STYLE_PREFIX}, {desc}"
    print(f'Generating {name} ({w}x{h}) [with bg]...')

    try:
        r = requests.post(f'{BASE_URL}/generate-image-pixflux', headers=HEADERS, json={
            'description': full_desc,
            'image_size': {'width': w, 'height': h},
            'outline': 'single color black outline',
            'shading': 'medium shading',
            'detail': 'medium detail',
            'no_background': False
        }, timeout=120)
        d = r.json()
        if 'image' in d:
            img_data = base64.b64decode(d['image']['base64'])
            open(out, 'wb').write(img_data)
            print(f'  OK {name}')
            return True
        else:
            print(f'  ERR {name}: {str(d)[:120]}')
            return False
    except Exception as e:
        print(f'  ERR {name}: {e}')
        return False

def make_9patch_from_panel(src_name, out_name, w, h):
    """Take a generated panel sprite and tile/stretch it to desired dimensions."""
    src = os.path.join(UI_DIR, src_name)
    out = os.path.join(UI_DIR, out_name)
    if os.path.exists(out):
        print(f'SKIP {out_name}')
        return
    if not os.path.exists(src):
        print(f'SKIP {out_name} (no source)')
        return
    img = Image.open(src).convert('RGBA')
    resized = img.resize((w, h), Image.NEAREST)
    resized.save(out)
    print(f'  Resized {src_name} -> {out_name} ({w}x{h})')


# ============================================================
# PANEL / FRAME SPRITES
# ============================================================

# Main panel frame - used for HUD panels, popup backgrounds
gen_with_bg('panel_frame_small.png',
    'small rectangular UI panel frame with brass riveted border, dark interior, ornate corners with gear motifs',
    96, 64)

gen_with_bg('panel_frame_medium.png',
    'medium rectangular UI panel frame with brass riveted border, dark brown interior, copper corner rivets, steampunk aesthetic',
    128, 96)

gen_with_bg('panel_frame_large.png',
    'large rectangular UI panel frame with ornate brass border, dark interior, gear decorations in corners, riveted edges',
    192, 128)

gen_with_bg('panel_frame_wide.png',
    'wide rectangular UI panel frame with brass riveted border, dark interior, steampunk gear corner decorations',
    192, 64)

# Popup/dialog frame
gen_with_bg('dialog_frame.png',
    'ornate steampunk dialog box frame with brass gears in corners, riveted border, dark interior, copper trim',
    160, 128)

# ============================================================
# HEALTH / XP / PROGRESS BARS
# ============================================================

# Health bar frame
gen('bar_frame_hp.png',
    'horizontal health bar frame with brass border and gear decorations on ends, empty interior, ornate steampunk',
    96, 20)

# Health bar fill (will be tinted/stretched in code)
gen_with_bg('bar_fill_hp.png',
    'glowing green liquid health bar fill, bubbling potion fluid inside glass tube, steampunk gauge',
    88, 14)

# XP bar frame
gen('bar_frame_xp.png',
    'thin horizontal experience bar frame with copper border, small gear on left end, steampunk gauge',
    96, 12)

# Timer/progress bar frame
gen('bar_frame_timer.png',
    'horizontal timer bar frame with brass border, clock gears decorating ends, steampunk hourglass aesthetic',
    96, 16)

# ============================================================
# BUTTONS
# ============================================================

gen_with_bg('button_normal.png',
    'rectangular steampunk button with brass border and rivets, dark metal interior, slightly raised 3D look',
    80, 28)

gen_with_bg('button_hover.png',
    'rectangular steampunk button glowing warm, brass border with rivets, lit up interior, warm orange glow, pressed state',
    80, 28)

gen_with_bg('button_green.png',
    'rectangular steampunk button with brass border, green glowing interior, copper rivets, action button',
    80, 28)

gen_with_bg('button_red.png',
    'rectangular steampunk button with brass border, red glowing interior, danger button, copper rivets',
    80, 28)

# ============================================================
# DECORATIVE ELEMENTS
# ============================================================

# Gears (for spinning decorations)
gen('gear_large.png',
    'large brass gear cog wheel with teeth, metallic copper shading, industrial steampunk, single gear front view',
    48, 48)

gen('gear_small.png',
    'small brass gear cog wheel with teeth, copper metallic, steampunk industrial, single gear front view',
    24, 24)

gen('gear_medium.png',
    'medium brass gear cog with teeth, copper shading, steampunk, single gear front view',
    32, 32)

# Rivets/bolts
gen('rivet.png',
    'single brass rivet bolt head, round metallic, steampunk, tiny',
    8, 8)

# Decorative divider line
gen('divider_horizontal.png',
    'horizontal ornate steampunk divider line with gear in center, brass copper, decorative separator',
    128, 12)

# Corner bracket decorations
gen('corner_bracket_tl.png',
    'top-left ornate corner bracket decoration, brass copper, steampunk, L-shaped with gear accent',
    24, 24)

gen('corner_bracket_tr.png',
    'top-right ornate corner bracket decoration, brass copper, steampunk, reversed L-shape with gear accent',
    24, 24)

gen('corner_bracket_bl.png',
    'bottom-left ornate corner bracket decoration, brass copper, steampunk, inverted L-shape with gear accent',
    24, 24)

gen('corner_bracket_br.png',
    'bottom-right ornate corner bracket decoration, brass copper, steampunk, reversed inverted L-shape with gear',
    24, 24)

# Steam pipe horizontal
gen('pipe_horizontal.png',
    'horizontal copper steam pipe with rivets and joints, steampunk industrial, side view',
    128, 12)

# ============================================================
# ICONS
# ============================================================

# Heart icon (replace existing basic one)
gen('icon_heart.png',
    'glowing red crystal heart icon, steampunk brass frame around heart, health icon for game HUD',
    24, 24)

# Shield icon
gen('icon_shield.png',
    'brass steampunk shield icon with gear emblem, defense icon',
    24, 24)

# Skull icon (for game over)
gen('icon_skull.png',
    'steampunk brass skull icon with gear eye, death icon, dark copper',
    32, 32)

# Anvil icon (for crafting)
gen('icon_anvil.png',
    'steampunk anvil icon with hammer, crafting icon, brass copper',
    24, 24)

# Wrench icon (for upgrades/buildings)
gen('icon_wrench.png',
    'steampunk wrench tool icon, brass copper, upgrade icon',
    24, 24)

# Bag icon (for salvage)
gen('icon_bag.png',
    'steampunk leather bag satchel icon, brass buckle, inventory icon',
    24, 24)

# Clock/timer icon
gen('icon_clock.png',
    'steampunk pocket watch clock icon, brass gears visible, timer icon',
    24, 24)

# Level up star
gen('icon_levelup.png',
    'glowing golden star icon with gear border, level up icon, steampunk',
    32, 32)

# Perk icons
gen('icon_perk_hp.png',
    'red heart with plus sign, health upgrade perk icon, steampunk brass frame, pixel art',
    28, 28)

gen('icon_perk_speed.png',
    'blue lightning bolt speed icon, steampunk brass frame, fast movement perk, pixel art',
    28, 28)

gen('icon_perk_damage.png',
    'orange flame sword damage icon, steampunk brass frame, attack perk, pixel art',
    28, 28)

gen('icon_perk_defense.png',
    'grey steel shield defense icon, steampunk brass frame, armor perk, pixel art',
    28, 28)

# ============================================================
# TITLE / LOGO
# ============================================================

gen('title_scrapwright.png',
    'game title text SCRAPWRIGHT in ornate steampunk brass lettering with gears, copper metallic text, game logo',
    256, 64)

gen('title_decoration.png',
    'ornate horizontal steampunk decoration bar with gears and copper pipes, title underline, symmetrical',
    200, 16)

# ============================================================
# BACKGROUNDS / OVERLAYS
# ============================================================

gen_with_bg('bg_vignette_dark.png',
    'dark vignette overlay, dark edges fading to transparent center, subtle steampunk texture',
    128, 128)

gen_with_bg('bg_panel_texture.png',
    'dark brown leather texture with subtle brass rivet pattern, steampunk panel background, seamless',
    64, 64)

# ============================================================
# CARD / SLOT FRAMES
# ============================================================

gen_with_bg('card_frame.png',
    'rectangular card frame with brass riveted border, dark interior, steampunk perk card, copper corners',
    64, 80)

gen('slot_frame.png',
    'square inventory slot frame with brass border, empty interior, steampunk item slot, copper rivets in corners',
    36, 36)

# ============================================================
# SPARK / PARTICLE SPRITES
# ============================================================

gen('particle_spark.png',
    'tiny golden spark particle, glowing ember, single bright point with small glow, steampunk',
    8, 8)

gen('particle_ember.png',
    'small red orange ember particle, glowing hot coal, tiny fire particle',
    8, 8)

gen('particle_steam.png',
    'small white steam puff cloud, tiny vapor wisp, steampunk steam particle',
    12, 12)

# ============================================================
# MATERIAL ICONS (upgraded versions of existing ones)
# ============================================================

gen('mat_icon_iron.png',
    'iron scrap metal chunk icon with brass frame, steampunk material icon, pixel art',
    24, 24)

gen('mat_icon_timber.png',
    'wooden timber plank icon with brass frame, steampunk material icon, pixel art',
    24, 24)

gen('mat_icon_fuel.png',
    'fuel canister icon with brass frame, steampunk material icon, glowing orange, pixel art',
    24, 24)

gen('mat_icon_organic.png',
    'green organic plant material icon with brass frame, steampunk material icon, pixel art',
    24, 24)

gen('mat_icon_stone.png',
    'stone rock chunk icon with brass frame, steampunk material icon, pixel art',
    24, 24)

gen('mat_icon_blueprint.png',
    'blueprint scroll paper icon with brass frame, steampunk material icon, pixel art',
    24, 24)


print('\n=== All UI sprite generation complete! ===')
print(f'Output directory: {UI_DIR}')

# List all generated files
files = sorted(os.listdir(UI_DIR))
png_files = [f for f in files if f.endswith('.png') and not f.endswith('.import')]
print(f'Total PNG files: {len(png_files)}')
for f in png_files:
    sz = os.path.getsize(os.path.join(UI_DIR, f))
    print(f'  {f} ({sz} bytes)')
