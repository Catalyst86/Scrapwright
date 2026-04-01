"""Generate base hub background and scrapwright character via PixelLab API."""
import requests, base64, os
from PIL import Image

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
H = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
BASE_URL = 'https://api.pixellab.ai/v1'
SPRITES = r'C:\Users\danie\Desktop\roguelite\assets\sprites'

def gen(name, desc, w, h, folder, no_bg=True):
    out = os.path.join(SPRITES, folder, name)
    if os.path.exists(out):
        print(f'SKIP {name}')
        return True
    os.makedirs(os.path.dirname(out), exist_ok=True)
    print(f'Generating {name} ({w}x{h})...')
    r = requests.post(f'{BASE_URL}/generate-image-pixflux', headers=H, json={
        'description': desc,
        'image_size': {'width': w, 'height': h},
        'outline': 'single color black outline',
        'shading': 'medium shading',
        'detail': 'medium detail',
        'no_background': no_bg
    }, timeout=120)
    d = r.json()
    if 'image' in d:
        open(out, 'wb').write(base64.b64decode(d['image']['base64']))
        print(f'OK {name}')
        return True
    else:
        print(f'ERR {name}: {str(d)[:200]}')
        return False

# Generate bg as 4 tiles (128x128 each) and stitch into 512x256
# Left part - workshop with workbench and pipes
tiles = []
descs = [
    'steampunk underground workshop corner with rusty pipes and wooden workbench dim orange lighting pixel art scene',
    'steampunk scrapyard interior with forge fire anvil and hanging tools dim orange lighting pixel art scene',
    'steampunk underground workshop with garden plants growing through rubble dim orange lighting pixel art scene',
    'steampunk scrapyard corner with scrap metal heap and armory weapon rack dim orange lighting pixel art scene',
]

success = True
for i, desc in enumerate(descs):
    name = f'base_hub_bg_tile_{i}.png'
    if not gen(name, desc, 128, 128, 'base', no_bg=False):
        success = False

# Stitch tiles into a 2x2 grid -> 256x256, then scale to 480x270
if success:
    out_path = os.path.join(SPRITES, 'base', 'base_hub_bg.png')
    if not os.path.exists(out_path):
        tiles_img = []
        for i in range(4):
            tile_path = os.path.join(SPRITES, 'base', f'base_hub_bg_tile_{i}.png')
            tiles_img.append(Image.open(tile_path).convert('RGBA'))
        
        bg = Image.new('RGBA', (256, 256))
        bg.paste(tiles_img[0], (0, 0))
        bg.paste(tiles_img[1], (128, 0))
        bg.paste(tiles_img[2], (0, 128))
        bg.paste(tiles_img[3], (128, 128))
        bg = bg.resize((480, 270), Image.NEAREST)
        bg.save(out_path)
        print(f'OK base_hub_bg.png (stitched 480x270)')

# Scrapwright NPC character
gen('scrapwright_npc.png',
    'small steampunk tinkerer craftsman character with goggles toolbelt and wrench standing idle facing forward pixel art',
    64, 64, 'base', no_bg=True)

print('All done!')
