"""
Re-generate key UI panel sprites using Bitforge with style_image for consistency.
Uses the panel_frame_small.png as style reference across all panels.
"""

import requests, base64, os
from PIL import Image
import io

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
BASE_URL = 'https://api.pixellab.ai/v1'
UI_DIR = r'C:\Users\danie\Desktop\roguelite\assets\sprites\ui'

def load_b64(path):
    return base64.b64encode(open(path, 'rb').read()).decode()

# Use our best panel as style reference
STYLE_REF = load_b64(os.path.join(UI_DIR, 'panel_frame_small.png'))

def gen_bitforge(name, desc, w, h, style_strength=60, no_bg=False, force=False):
    out = os.path.join(UI_DIR, name)
    if os.path.exists(out) and not force:
        print(f'SKIP {name}')
        return

    # bitforge max is 200x200
    api_w = min(w, 200)
    api_h = min(h, 200)

    print(f'Generating {name} ({api_w}x{api_h}) via Bitforge...')
    try:
        body = {
            'description': f'steampunk pixel art game UI, {desc}',
            'image_size': {'width': api_w, 'height': api_h},
            'style_image': {'base64': STYLE_REF},
            'style_strength': style_strength,
            'no_background': no_bg,
        }
        r = requests.post(f'{BASE_URL}/generate-image-bitforge', headers=HEADERS, json=body, timeout=120)
        d = r.json()
        if 'image' in d:
            img_data = base64.b64decode(d['image']['base64'])
            img = Image.open(io.BytesIO(img_data)).convert('RGBA')
            # Scale up if we needed to shrink for API
            if w != api_w or h != api_h:
                img = img.resize((w, h), Image.NEAREST)
            img.save(out)
            print(f'  OK {name}')
        else:
            print(f'  ERR {name}: {str(d)[:200]}')
    except Exception as e:
        print(f'  ERR {name}: {e}')

# Re-generate panels with consistent style
gen_bitforge('panel_frame_small.png',
    'small rectangular panel frame with brass riveted border, dark interior, ornate steampunk corners',
    96, 64, force=True)

gen_bitforge('panel_frame_medium.png',
    'medium rectangular panel frame with brass riveted border, dark brown interior, copper corner rivets',
    128, 96, force=True)

gen_bitforge('panel_frame_large.png',
    'large rectangular panel frame with ornate brass border, dark interior, gear decorations in corners, riveted edges',
    192, 128, force=True)

gen_bitforge('panel_frame_wide.png',
    'wide rectangular panel frame with brass riveted border, dark interior, steampunk gear corner pieces',
    192, 64, force=True)

gen_bitforge('dialog_frame.png',
    'ornate dialog box frame with brass gears in corners, riveted border, dark interior, copper trim',
    160, 128, force=True)

# Buttons with consistent style
gen_bitforge('button_normal.png',
    'rectangular button with brass border and rivets, dark metal interior, slightly raised 3D look',
    80, 32, style_strength=50, force=True)

gen_bitforge('button_hover.png',
    'rectangular button glowing warm, brass border with rivets, lit up warm orange interior',
    80, 32, style_strength=50, force=True)

gen_bitforge('button_green.png',
    'rectangular button with brass border, green glowing interior, copper rivets, action confirm button',
    80, 32, style_strength=50, force=True)

gen_bitforge('button_red.png',
    'rectangular button with brass border, red glowing interior, danger cancel button, copper rivets',
    80, 32, style_strength=50, force=True)

# Card frame (for perk cards)
gen_bitforge('card_frame.png',
    'tall rectangular card frame with brass riveted border, dark interior, steampunk perk card with copper corners',
    64, 80, style_strength=55, force=True)

# Title
gen_bitforge('title_scrapwright.png',
    'game title SCRAPWRIGHT in ornate steampunk brass lettering with gears and copper decoration, game logo text',
    200, 64, style_strength=40, force=True)

# Bar frames
gen_bitforge('bar_frame_hp.png',
    'horizontal health bar frame with brass border and small gear decorations on ends, steampunk gauge, empty interior',
    96, 32, style_strength=50, no_bg=True, force=True)

gen_bitforge('bar_frame_timer.png',
    'horizontal timer bar frame with brass border, clock gear decorations, steampunk progress bar frame',
    96, 32, style_strength=50, no_bg=True, force=True)

# Slot frame
gen_bitforge('slot_frame.png',
    'square inventory slot frame with brass corner rivets, empty center, steampunk item slot',
    36, 36, style_strength=50, no_bg=True, force=True)

print('\n=== Bitforge style-consistent generation complete! ===')
