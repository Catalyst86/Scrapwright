"""
Generate proper 4-frame animation sprite sheets from SINGLE base sprites.
Key principle: ALL player animations derive from player_idle.png for consistency.
Each enemy type uses its own single static sprite for all its animations.

Walk cycles simulate motion with:
- Vertical bob (contact/passing phases)
- Squash/stretch (compression on contact, elongation on passing)
- Alternating lean (body tilt to simulate weight shift)
- Horizontal sway for directional emphasis
"""
import os, math
from PIL import Image, ImageDraw, ImageFilter

SPRITES = r'C:\Users\danie\Desktop\roguelite\assets\sprites'
ANIM = os.path.join(SPRITES, 'animations')
os.makedirs(ANIM, exist_ok=True)


def load_base(path, size=64):
    """Load and normalize a sprite to target size."""
    if not os.path.exists(path):
        print(f'  MISSING: {path}')
        return None
    return Image.open(path).convert('RGBA').resize((size, size), Image.NEAREST)


def paste_centered(canvas, sprite, cx, cy):
    """Paste sprite centered at (cx, cy) on canvas."""
    x = int(cx - sprite.width / 2)
    y = int(cy - sprite.height / 2)
    canvas.paste(sprite, (x, y), sprite)


def transform_frame(img, dy=0, dx=0, scale_x=1.0, scale_y=1.0, angle=0):
    """
    Apply transformations to a sprite, anchored at bottom-center.
    dy: vertical shift (negative = up)
    dx: horizontal shift
    scale_x/scale_y: squash/stretch
    angle: rotation in degrees
    """
    w, h = img.size

    # Scale
    new_w = max(1, int(w * scale_x))
    new_h = max(1, int(h * scale_y))
    scaled = img.resize((new_w, new_h), Image.NEAREST)

    # Rotate around center
    if angle != 0:
        scaled = scaled.rotate(angle, resample=Image.NEAREST, expand=False,
                               center=(new_w // 2, new_h // 2))

    # Place on 64x64 canvas, anchored at bottom-center
    canvas = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ox = (w - new_w) // 2 + int(dx)
    oy = (h - new_h) + int(dy)  # anchor to bottom
    canvas.paste(scaled, (ox, oy), scaled)
    return canvas


def make_sheet(frames, out_path):
    """Combine list of 64x64 frames into a 256x64 horizontal strip."""
    sheet = Image.new('RGBA', (256, 64), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * 64, 0), f)
    sheet.save(out_path)
    return True


def mirror_h(img):
    """Horizontal mirror."""
    return img.transpose(Image.FLIP_LEFT_RIGHT)


# =====================================================================
# WALK CYCLE — 4-frame bounce walk
# Frame 0: Right foot contact (squash down, lean right)
# Frame 1: Right foot passing (stretch up, centered)
# Frame 2: Left foot contact (squash down, lean left)
# Frame 3: Left foot passing (stretch up, centered)
# =====================================================================

def make_walk_cycle(base, direction='s'):
    """
    Generate 4 walk frames from a single base sprite.
    direction: 's'outh, 'n'orth, 'e'ast, 'w'est
    """
    # Direction-specific emphasis
    lean_dir = 0  # extra horizontal lean for east/west
    vert_offset = 0  # vertical offset for north (walking away = slightly smaller/higher)
    if direction == 'e':
        lean_dir = 1
    elif direction == 'w':
        lean_dir = -1
    elif direction == 'n':
        vert_offset = -2  # slightly higher, walking away

    frames = []

    # Frame 0: Contact right — body drops, squashes wide, leans right
    f = transform_frame(base, dy=3 + vert_offset, dx=1 + lean_dir, scale_x=1.08, scale_y=0.92, angle=-3)
    frames.append(f)

    # Frame 1: Passing — body rises, stretches tall, lean opposite
    f = transform_frame(base, dy=-3 + vert_offset, dx=lean_dir, scale_x=0.93, scale_y=1.07, angle=1)
    frames.append(f)

    # Frame 2: Contact left — body drops, squashes wide, leans left
    f = transform_frame(base, dy=3 + vert_offset, dx=-1 + lean_dir, scale_x=1.08, scale_y=0.92, angle=3)
    frames.append(f)

    # Frame 3: Passing — body rises, stretches tall, lean opposite
    f = transform_frame(base, dy=-3 + vert_offset, dx=lean_dir, scale_x=0.93, scale_y=1.07, angle=-1)
    frames.append(f)

    return frames


def make_attack_cycle(base):
    """4-frame attack: wind-up → swing → impact → recover."""
    frames = []

    # Frame 0: Wind-up — pull back, lean back
    f = transform_frame(base, dy=1, dx=-3, scale_x=1.05, scale_y=0.95, angle=8)
    frames.append(f)

    # Frame 1: Swing forward — stretch toward target
    f = transform_frame(base, dy=-1, dx=2, scale_x=0.90, scale_y=1.10, angle=-5)
    frames.append(f)

    # Frame 2: Impact — full extension, squash at contact
    f = transform_frame(base, dy=-2, dx=4, scale_x=0.85, scale_y=1.15, angle=-10)
    frames.append(f)

    # Frame 3: Recover — bounce back to near-neutral
    f = transform_frame(base, dy=1, dx=0, scale_x=1.03, scale_y=0.97, angle=2)
    frames.append(f)

    return frames


def make_hurt_cycle(base):
    """4-frame hurt: hit → recoil → stagger → recover."""
    frames = []

    # Frame 0: Hit impact — squash
    f = transform_frame(base, dy=2, dx=0, scale_x=1.12, scale_y=0.88, angle=0)
    frames.append(f)

    # Frame 1: Recoil — knocked back, tilted
    f = transform_frame(base, dy=0, dx=-4, scale_x=0.95, scale_y=1.05, angle=12)
    frames.append(f)

    # Frame 2: Stagger — recovering, still off-balance
    f = transform_frame(base, dy=1, dx=-2, scale_x=1.0, scale_y=1.0, angle=5)
    frames.append(f)

    # Frame 3: Recover — back to normal
    f = transform_frame(base, dy=0, dx=0, scale_x=1.0, scale_y=1.0, angle=0)
    frames.append(f)

    return frames


def make_death_cycle(base):
    """4-frame death: flinch → topple → fall → flatten+fade."""
    frames = []

    # Frame 0: Flinch — recoil up
    f = transform_frame(base, dy=-2, dx=0, scale_x=0.92, scale_y=1.08, angle=-5)
    frames.append(f)

    # Frame 1: Toppling — starting to fall
    f = transform_frame(base, dy=2, dx=3, scale_x=1.0, scale_y=1.0, angle=25)
    frames.append(f)

    # Frame 2: Falling — more rotation, moving down
    f = transform_frame(base, dy=6, dx=5, scale_x=1.1, scale_y=0.9, angle=55)
    frames.append(f)

    # Frame 3: Flat on ground — very squashed, faded
    f = transform_frame(base, dy=10, dx=5, scale_x=1.4, scale_y=0.5, angle=80)
    # Fade alpha
    r, g, b, a = f.split()
    a = a.point(lambda x: int(x * 0.35))
    f = Image.merge('RGBA', (r, g, b, a))
    frames.append(f)

    return frames


def make_flyer_cycle(base):
    """4-frame fly: wing-up → glide-down → wing-down → glide-up. More dramatic vertical."""
    frames = []

    # Frame 0: Wings up, body high — wide and short
    f = transform_frame(base, dy=-5, dx=0, scale_x=1.18, scale_y=0.82, angle=0)
    frames.append(f)

    # Frame 1: Gliding down — normal shape, slight tilt
    f = transform_frame(base, dy=-1, dx=1, scale_x=1.02, scale_y=0.98, angle=-4)
    frames.append(f)

    # Frame 2: Wings down, body low — tall and narrow
    f = transform_frame(base, dy=4, dx=0, scale_x=0.82, scale_y=1.18, angle=0)
    frames.append(f)

    # Frame 3: Gliding up — normal shape, opposite tilt
    f = transform_frame(base, dy=-1, dx=-1, scale_x=1.02, scale_y=0.98, angle=4)
    frames.append(f)

    return frames


# =====================================================================
# GENERATE ALL SHEETS
# =====================================================================

print("=== PLAYER ANIMATIONS ===")
print("Using player_idle.png as SINGLE base for all player animations")

player_base = load_base(os.path.join(SPRITES, 'player', 'player_idle.png'))
if player_base:
    # Walk cycles — all 4 directions from same base
    for d in ['s', 'n', 'e', 'w']:
        frames = make_walk_cycle(player_base, d)
        out = os.path.join(ANIM, f'player_walk_{d}_sheet.png')
        make_sheet(frames, out)
        print(f'  OK player_walk_{d}_sheet.png')

    # Attack
    frames = make_attack_cycle(player_base)
    make_sheet(frames, os.path.join(ANIM, 'player_attack_sheet.png'))
    print(f'  OK player_attack_sheet.png')

    # Hurt
    frames = make_hurt_cycle(player_base)
    make_sheet(frames, os.path.join(ANIM, 'player_hurt_sheet.png'))
    print(f'  OK player_hurt_sheet.png')

    # Death
    frames = make_death_cycle(player_base)
    make_sheet(frames, os.path.join(ANIM, 'player_death_sheet.png'))
    print(f'  OK player_death_sheet.png')

print()
print("=== ENEMY ANIMATIONS ===")
print("Each enemy uses its own static sprite as base")

for enemy in ['rusher', 'shooter', 'tank', 'exploder']:
    base = load_base(os.path.join(SPRITES, 'enemies', f'enemy_{enemy}.png'))
    if not base:
        continue

    # Walk
    frames = make_walk_cycle(base)
    make_sheet(frames, os.path.join(ANIM, f'enemy_{enemy}_walk_sheet.png'))
    print(f'  OK enemy_{enemy}_walk_sheet.png')

    # Die
    frames = make_death_cycle(base)
    make_sheet(frames, os.path.join(ANIM, f'enemy_{enemy}_die_sheet.png'))
    print(f'  OK enemy_{enemy}_die_sheet.png')

# Flyer gets special wing-flap animation
flyer_base = load_base(os.path.join(SPRITES, 'enemies', 'enemy_flyer.png'))
if flyer_base:
    frames = make_flyer_cycle(flyer_base)
    make_sheet(frames, os.path.join(ANIM, 'enemy_flyer_walk_sheet.png'))
    print(f'  OK enemy_flyer_walk_sheet.png')

    frames = make_death_cycle(flyer_base)
    make_sheet(frames, os.path.join(ANIM, 'enemy_flyer_die_sheet.png'))
    print(f'  OK enemy_flyer_die_sheet.png')

print()
print("All animation sheets generated from consistent base sprites!")
