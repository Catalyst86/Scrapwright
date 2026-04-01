import requests, base64, os, time, json
from PIL import Image
import io

API_KEY = '033683bf-7368-465f-81a8-6e01192d8a1b'
BASE = 'https://api.pixellab.ai/v2'
H = {'Authorization': f'Bearer {API_KEY}', 'Content-Type': 'application/json'}

SPRITES = r'C:\Users\danie\Desktop\roguelite\assets\sprites\enemies'
ANIMS = r'C:\Users\danie\Desktop\roguelite\assets\sprites\animations'

ENEMIES = {
    "rusher": "lunging forward biting aggressively",
    "exploder": "swelling up and exploding",
    "flyer": "diving down swooping attack",
    "spark_bug": "zapping with electric spark",
    "scrap_sentinel": "swinging metal arm attack",
    "junkyard_mech": "stomping and punching",
    "spore_walker": "releasing spore cloud",
    "fungal_brute": "charging forward headbutt",
    "mycelium_sniper": "shooting fungal projectile",
    "spore_mother": "summoning spore burst",
    "fungal_titan": "slamming fists creating shockwave",
    "magma_imp": "throwing fireball",
    "lava_lobber": "lobbing molten rock",
    "obsidian_golem": "crushing punch downward",
    "ember_drake": "flame breath attack",
    "frost_sprite": "casting ice shard spell",
    "ice_archer": "shooting ice arrow",
    "frost_warden": "swinging ice blade",
    "glacial_hulk": "ground pound ice slam",
    "crystal_bat": "sonic screech attack",
    "crystal_colossus": "crystal beam blast",
    "steam_turret": "rapid fire steam shots",
    "gear_drone": "spinning blade attack",
    "shadow_crawler": "lunging claw swipe",
    "void_weaver": "casting dark void spell",
    "abyssal_knight": "sword slash combo",
    "the_devourer": "massive bite chomp",
    "the_architect": "summoning energy blast",
    "scrap_king": "throwing scrap projectiles",
}

ok = 0
fail = 0
for name, action in ENEMIES.items():
    out = os.path.join(ANIMS, f'enemy_{name}_attack_sheet.png')
    if os.path.exists(out):
        print(f'SKIP {name} (already exists)')
        ok += 1
        continue
    
    src = os.path.join(SPRITES, f'enemy_{name}.png')
    if not os.path.exists(src):
        print(f'SKIP {name} (no sprite)')
        continue
    
    # Load and resize if needed
    img = Image.open(src).convert('RGBA')
    if img.width > 256 or img.height > 256:
        img.thumbnail((256, 256), Image.NEAREST)
    buf = io.BytesIO()
    img.save(buf, 'PNG')
    b64 = base64.b64encode(buf.getvalue()).decode()
    
    print(f'[{ok+fail+1}/{len(ENEMIES)}] {name} -- "{action}" ({img.width}x{img.height})')
    
    try:
        resp = requests.post(f'{BASE}/animate-with-text-v3', headers=H, json={
            'first_frame': {'base64': b64},
            'action': action,
            'frame_count': 8
        }, timeout=180)
        
        if resp.status_code == 429:
            print(f'  RATE LIMITED -- waiting 30s...')
            time.sleep(30)
            resp = requests.post(f'{BASE}/animate-with-text-v3', headers=H, json={
                'first_frame': {'base64': b64},
                'action': action,
                'frame_count': 8
            }, timeout=180)
        
        if resp.status_code == 200:
            data = resp.json()
            frames = data.get('images', [])
            print(f'  Got {len(frames)} frames')
            
            # Decode frames
            pil_frames = []
            for f in frames:
                fd = base64.b64decode(f['base64'])
                pil_frames.append(Image.open(io.BytesIO(fd)).convert('RGBA'))
            
            if pil_frames:
                fw, fh = pil_frames[0].size
                sheet = Image.new('RGBA', (fw * len(pil_frames), fh), (0,0,0,0))
                for i, pf in enumerate(pil_frames):
                    sheet.paste(pf, (i * fw, 0))
                sheet.save(out)
                print(f'  SAVED: {out}')
                ok += 1
            else:
                print(f'  ERROR: no frames')
                fail += 1
        else:
            print(f'  ERROR: HTTP {resp.status_code} -- {resp.text[:100]}')
            fail += 1
    except Exception as e:
        print(f'  ERROR: {e}')
        fail += 1
    
    # Small delay between requests to avoid rate limiting
    time.sleep(3)

print(f'\nDONE: {ok} succeeded, {fail} failed')
