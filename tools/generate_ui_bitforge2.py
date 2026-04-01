"""Re-generate UI sprites with Bitforge, resizing style_image to match each target size."""
import requests, base64, os
from PIL import Image
import io

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
HEADERS = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
BASE_URL = 'https://api.pixellab.ai/v1'
UI_DIR = r'C:\Users\danie\Desktop\roguelite\assets\sprites\ui'

style_img = Image.open(os.path.join(UI_DIR, 'panel_frame_small.png')).convert('RGBA')

def get_style_b64(w, h):
    resized = style_img.resize((w, h), Image.NEAREST)
    buf = io.BytesIO()
    resized.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode()

def gen(name, desc, w, h, no_bg=False, style_strength=55):
    out = os.path.join(UI_DIR, name)
    api_w, api_h = min(w, 200), min(h, 200)
    print(f'Generating {name} ({api_w}x{api_h})...')
    try:
        r = requests.post(f'{BASE_URL}/generate-image-bitforge', headers=HEADERS, json={
            'description': f'steampunk pixel art game UI, {desc}',
            'image_size': {'width': api_w, 'height': api_h},
            'style_image': {'base64': get_style_b64(api_w, api_h)},
            'style_strength': style_strength,
            'no_background': no_bg,
        }, timeout=120)
        d = r.json()
        if 'image' in d:
            img_data = base64.b64decode(d['image']['base64'])
            img = Image.open(io.BytesIO(img_data)).convert('RGBA')
            if w != api_w or h != api_h:
                img = img.resize((w, h), Image.NEAREST)
            img.save(out)
            print(f'  OK {name}')
        else:
            print(f'  ERR {name}: {str(d)[:200]}')
    except Exception as e:
        print(f'  ERR {name}: {e}')

# Panels
gen('panel_frame_medium.png', 'medium rectangular panel frame with brass riveted border, dark brown interior, copper corner rivets', 128, 96)
gen('panel_frame_large.png', 'large rectangular panel frame with ornate brass border, dark interior, gear corners, riveted edges', 192, 128)
gen('panel_frame_wide.png', 'wide rectangular panel frame with brass riveted border, dark interior, gear corner decorations', 192, 64)
gen('dialog_frame.png', 'ornate dialog box frame with brass gears in corners, riveted border, dark interior', 160, 128)

# Buttons
gen('button_normal.png', 'small rectangular button dark metal interior, brass border rivets, 3D raised look', 80, 32, style_strength=45)
gen('button_hover.png', 'small rectangular button warm glow, brass border rivets, lit up orange interior', 80, 32, style_strength=45)
gen('button_green.png', 'small rectangular button green glowing interior, brass border rivets, confirm button', 80, 32, style_strength=45)
gen('button_red.png', 'small rectangular button red glowing interior, brass border rivets, danger button', 80, 32, style_strength=45)

# Cards and slots
gen('card_frame.png', 'tall rectangular card frame brass riveted border, dark interior, perk card copper corners', 64, 80, style_strength=50)
gen('slot_frame.png', 'square inventory slot frame brass corner rivets, empty center, item slot', 36, 36, no_bg=True, style_strength=50)

# Bars
gen('bar_frame_hp.png', 'horizontal health bar frame brass border, small gears on ends, gauge, empty interior', 96, 32, no_bg=True, style_strength=45)
gen('bar_frame_timer.png', 'horizontal timer bar frame brass border, clock gear decoration, progress bar', 96, 32, no_bg=True, style_strength=45)

# Title
gen('title_scrapwright.png', 'game title SCRAPWRIGHT ornate steampunk brass lettering gears copper decoration logo', 200, 64, style_strength=40)

print('\n=== Done! ===')
