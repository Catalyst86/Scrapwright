import requests, base64, os
from PIL import Image
import io

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
H = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}
BASE_URL = 'https://api.pixellab.ai/v1'
PROJECT = r'C:\Users\danie\Desktop\roguelite\assets\sprites'

def gen(name, desc, w=64, h=64, folder='player'):
    out = os.path.join(PROJECT, folder, name)
    if os.path.exists(out):
        print(f'SKIP {name}'); return
    for attempt in range(3):
        try:
            r = requests.post(f'{BASE_URL}/generate-image-pixflux', headers=H, json={
                'description': desc,
                'image_size': {'width': w, 'height': h},
                'outline': 'single color black outline',
                'shading': 'medium shading',
                'detail': 'medium detail',
                'no_background': True
            }, timeout=120)
            d = r.json()
            if 'image' in d:
                os.makedirs(os.path.dirname(out), exist_ok=True)
                open(out, 'wb').write(base64.b64decode(d['image']['base64']))
                print(f'OK {name}')
                return
            else:
                print(f'ERR {name}: {str(d)[:80]}')
                return
        except requests.exceptions.ReadTimeout:
            print(f'TIMEOUT {name} (attempt {attempt+1}/3)')
            if attempt == 2:
                print(f'FAILED {name}: all retries exhausted')

def load_b64(path):
    return base64.b64encode(open(path,'rb').read()).decode()

def make_static_sheet(src_path, out_path):
    """4-frame sheet from single sprite (used as animation fallback)"""
    if os.path.exists(out_path): return
    img = Image.open(src_path).convert('RGBA').resize((64,64))
    sheet = Image.new('RGBA', (256, 64), (0,0,0,0))
    for i in range(4):
        sheet.paste(img, (i*64, 0))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path)
    print(f'Sheet: {os.path.basename(out_path)}')

# --- Generate static sprites ---
gen('player_idle.png', 'tiny steampunk craftsman tinkerer with goggles and toolbelt facing south idle pose pixel art', folder='player')
gen('player_walk_s.png', 'tiny steampunk craftsman walking south pixel art', folder='player')
gen('player_hurt.png', 'tiny steampunk craftsman recoiling in pain pixel art', folder='player')
gen('player_death.png', 'tiny steampunk craftsman fallen dead pixel art', folder='player')
gen('player_salvage.png', 'tiny steampunk craftsman swinging pickaxe pixel art', folder='player')
gen('player_throw.png', 'tiny steampunk craftsman throwing object pixel art', folder='player')

gen('enemy_rusher.png', 'small goblin gremlin creature running melee fighter pixel art', folder='enemies')
gen('enemy_shooter.png', 'skeleton archer with bow pixel art', folder='enemies')
gen('enemy_tank.png', 'large stone golem heavy creature pixel art', folder='enemies')
gen('enemy_flyer.png', 'bat creature flying pixel art', folder='enemies')
gen('enemy_exploder.png', 'round bomb creature with lit fuse pixel art', folder='enemies')

gen('item_throwing_knife.png', 'throwing knife weapon pixel art', 32, 32, 'items')
gen('item_molotov.png', 'molotov cocktail bottle with rag pixel art', 32, 32, 'items')
gen('item_pipe_bomb.png', 'pipe bomb explosive pixel art', 32, 32, 'items')
gen('item_boomerang.png', 'wooden boomerang pixel art', 32, 32, 'items')
gen('mat_iron_scrap.png', 'iron scrap metal chunk pixel art', 32, 32, 'items')
gen('mat_timber.png', 'timber wood plank pixel art', 32, 32, 'items')
gen('mat_fuel.png', 'fuel canister pixel art', 32, 32, 'items')
gen('mat_organic.png', 'organic material plant material pixel art', 32, 32, 'items')
gen('mat_stone.png', 'stone rock chunk pixel art', 32, 32, 'items')
gen('mat_blueprint.png', 'blueprint scroll paper pixel art', 32, 32, 'items')
gen('salvage_tool_pickaxe.png', 'iron pickaxe tool pixel art', 32, 32, 'items')

gen('trap_spikes.png', 'floor spike trap pixel art', 48, 48, 'traps')
gen('trap_fire.png', 'fire trap flame pixel art', 48, 48, 'traps')
gen('trap_electric.png', 'electric trap lightning pixel art', 48, 48, 'traps')

gen('destructible_crate.png', 'wooden crate breakable prop pixel art', 48, 48, 'environment')
gen('destructible_barrel.png', 'wooden barrel breakable prop pixel art', 48, 48, 'environment')
gen('destructible_rubble.png', 'stone rubble pile pixel art', 48, 48, 'environment')
gen('destructible_corpse.png', 'defeated enemy corpse pixel art', 48, 48, 'environment')

gen('base_workbench.png', 'craftsman workbench with tools pixel art', 64, 64, 'base')
gen('base_forge.png', 'blacksmith forge with fire pixel art', 64, 64, 'base')
gen('base_garden.png', 'small garden plant bed pixel art', 64, 64, 'base')
gen('base_armory.png', 'armory weapons rack pixel art', 64, 64, 'base')
gen('base_scrapheap.png', 'scrap metal heap pile pixel art', 64, 64, 'base')

gen('ui_heart.png', 'pixel art heart health icon', 32, 32, 'ui')
gen('ui_bag.png', 'pixel art bag inventory icon', 32, 32, 'ui')

# --- Make animation sheets from static sprites ---
sprite_dir = os.path.join(PROJECT)
anim_dir = os.path.join(PROJECT, 'animations')
os.makedirs(anim_dir, exist_ok=True)

for enemy in ['rusher', 'shooter', 'tank', 'flyer', 'exploder']:
    src = os.path.join(sprite_dir, 'enemies', f'enemy_{enemy}.png')
    if os.path.exists(src):
        make_static_sheet(src, os.path.join(anim_dir, f'enemy_{enemy}_walk_sheet.png'))
        make_static_sheet(src, os.path.join(anim_dir, f'enemy_{enemy}_die_sheet.png'))

player_src = os.path.join(sprite_dir, 'player', 'player_idle.png')
if os.path.exists(player_src):
    for anim in ['walk_s', 'walk_n', 'walk_e', 'walk_w', 'attack', 'hurt', 'death']:
        make_static_sheet(player_src, os.path.join(anim_dir, f'player_{anim}_sheet.png'))

print('All sprites done!')
