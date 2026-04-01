import requests, base64, os, time
from PIL import Image

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
H = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
URL = 'https://api.pixellab.ai/v1/generate-image-pixflux'
D = r'C:\Users\danie\Desktop\roguelite\assets\sprites\enemies'
A = r'C:\Users\danie\Desktop\roguelite\assets\sprites\animations'

enemies = [
    ('enemy_crystal_bat.png', 'ice crystal bat frozen wings glowing blue pixel art'),
    ('enemy_gear_drone.png', 'small brass mechanical drone robot steampunk pixel art'),
    ('enemy_steam_turret.png', 'brass steam cannon turret steampunk pixel art'),
    ('enemy_brass_enforcer.png', 'brass robot soldier with shield steampunk pixel art'),
    ('enemy_spark_bug.png', 'tiny electric lightning bug glowing yellow pixel art'),
    ('enemy_shadow_crawler.png', 'dark shadow spider glowing purple eyes pixel art'),
    ('enemy_void_weaver.png', 'dark mage purple void energy robes pixel art'),
    ('enemy_abyssal_knight.png', 'heavy dark armored knight purple sword pixel art'),
    ('enemy_phantom.png', 'ghostly transparent spirit glowing eyes pixel art'),
]

for name, desc in enemies:
    out = os.path.join(D, name)
    if os.path.exists(out):
        print(f'SKIP {name}')
        continue

    print(f'Generating {name}...', end=' ', flush=True)
    for attempt in range(3):
        try:
            r = requests.post(URL, headers=H, json={
                'description': desc,
                'image_size': {'width': 64, 'height': 64},
                'outline': 'single color black outline',
                'shading': 'medium shading',
                'detail': 'medium detail',
                'no_background': True
            }, timeout=120)
            j = r.json()
            if 'image' in j:
                open(out, 'wb').write(base64.b64decode(j['image']['base64']))
                print(f'OK ({os.path.getsize(out)} bytes)')
                break
            else:
                print(f'ERR: {str(j)[:60]}')
        except Exception as e:
            print(f'RETRY {attempt+1}: {type(e).__name__}')
            time.sleep(5)
    time.sleep(2)

# Build walk/die sheets for all that exist
print('\nBuilding sprite sheets...')
all_new = [
    'frost_sprite', 'ice_archer', 'glacial_hulk', 'crystal_bat',
    'gear_drone', 'steam_turret', 'brass_enforcer', 'spark_bug',
    'shadow_crawler', 'void_weaver', 'abyssal_knight', 'phantom',
]

for e in all_new:
    src = os.path.join(D, f'enemy_{e}.png')
    walk_out = os.path.join(A, f'enemy_{e}_walk_sheet.png')
    die_out = os.path.join(A, f'enemy_{e}_die_sheet.png')

    if not os.path.exists(src):
        print(f'  MISSING {e}')
        continue
    if os.path.exists(walk_out):
        continue

    img = Image.open(src).convert('RGBA')
    w, h = img.size

    ws = Image.new('RGBA', (w*4, h), (0,0,0,0))
    for i in range(4): ws.paste(img, (i*w, 0))
    ws.save(walk_out)

    ds = Image.new('RGBA', (w*4, h), (0,0,0,0))
    for i in range(4):
        f = img.copy(); px = f.load()
        for x in range(w):
            for y in range(h):
                r,g,b,a = px[x,y]
                if a > 0: px[x,y] = (min(255,r+i*30), max(0,g-i*20), max(0,b-i*20), max(0,a-i*40))
        ds.paste(f, (i*w, 0))
    ds.save(die_out)
    print(f'  Sheet: {e}')

print('\nAll done!')
