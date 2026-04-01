"""
Scrapwright Intro Video Renderer v3 - Extended + Fully Animated
Canvas: 384x216 @ 24fps -> upscaled to 1920x1080 via ffmpeg nearest-neighbor.
Total duration: ~30s (longer, clearer storytelling)

Usage:
  python render_intro.py          # render all scenes + assemble
  python render_intro.py assemble # ffmpeg stitch only
"""
import os, sys, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance

# -- Paths --
ROOT = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(ROOT, 'assets')
SCENES = os.path.join(ROOT, 'scenes')
OUTPUT = os.path.join(ROOT, 'output')
SPRITES = os.path.join(os.path.dirname(ROOT), 'assets', 'sprites')

W, H = 384, 216
FPS = 24

# -- Animation frame counts (verified) --
ANIM_FRAMES = {'run': 6, 'idle': 8, 'bark': 6, 'jump': 4}

def ensure_dir(p):
    os.makedirs(p, exist_ok=True)

# ======================================================
# SPRITE LOADING
# ======================================================

_sprite_cache = {}
_asset_cache = {}

def load_sprite_frame(outfit, anim, direction, frame_num):
    """Load individual player sprite frame. Returns 92x92 RGBA."""
    key = (outfit, anim, direction, frame_num)
    if key in _sprite_cache:
        return _sprite_cache[key]
    path = os.path.join(SPRITES, 'player', outfit, anim, direction, f'frame_{frame_num:03d}.png')
    if os.path.exists(path):
        img = Image.open(path).convert('RGBA')
    else:
        img = Image.new('RGBA', (92, 92), (0, 0, 0, 0))
    _sprite_cache[key] = img
    return img

def load_anim_sequence(outfit, anim, direction):
    """Load all frames for an animation."""
    count = ANIM_FRAMES.get(anim, 4)
    return [load_sprite_frame(outfit, anim, direction, i) for i in range(count)]

def load_asset(name, fallback_size=(64, 64)):
    if name in _asset_cache:
        return _asset_cache[name].copy()
    path = os.path.join(ASSETS, name)
    if os.path.exists(path):
        img = Image.open(path).convert('RGBA')
    else:
        img = Image.new('RGBA', fallback_size, (0, 0, 0, 0))
    _asset_cache[name] = img
    return img.copy()

def load_asset_or_procedural(name, fallback_fn, *args):
    """Load from file if exists, otherwise call fallback_fn to generate."""
    path = os.path.join(ASSETS, name)
    if os.path.exists(path) and os.path.getsize(path) > 100:
        return Image.open(path).convert('RGBA')
    return fallback_fn(*args)

# ======================================================
# EFFECTS ENGINE
# ======================================================

def lerp(a, b, t):
    return a + (b - a) * max(0.0, min(1.0, t))

def ease_in(t):
    return t * t

def ease_out(t):
    return 1 - (1 - t) ** 2

def ease_in_out(t):
    return t * t * (3 - 2 * t)

def ease_out_bounce(t):
    if t < 1/2.75:
        return 7.5625 * t * t
    elif t < 2/2.75:
        t -= 1.5/2.75
        return 7.5625 * t * t + 0.75
    elif t < 2.5/2.75:
        t -= 2.25/2.75
        return 7.5625 * t * t + 0.9375
    else:
        t -= 2.625/2.75
        return 7.5625 * t * t + 0.984375

def paste_alpha(canvas, sprite, x, y):
    """Paste sprite with top-left at (x,y) respecting alpha."""
    if sprite.width <= 0 or sprite.height <= 0:
        return
    ix, iy = int(x), int(y)
    # Clamp to canvas bounds
    if ix >= canvas.width or iy >= canvas.height:
        return
    if ix + sprite.width <= 0 or iy + sprite.height <= 0:
        return
    canvas.paste(sprite, (ix, iy), sprite)

def paste_centered(canvas, sprite, cx, cy):
    paste_alpha(canvas, sprite, cx - sprite.width // 2, cy - sprite.height // 2)

def create_glow(color, radius, intensity=1.0):
    if radius < 2:
        return Image.new('RGBA', (4, 4), (0, 0, 0, 0))
    size = radius * 2
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for r in range(radius, 0, -1):
        t = r / radius
        alpha = int(255 * intensity * (1 - t) * (1 - t))
        alpha = max(0, min(255, alpha))
        draw.ellipse([radius - r, radius - r, radius + r, radius + r],
                     fill=(*color, alpha))
    return glow

def apply_vignette(img, strength=0.6, color=(0, 0, 0)):
    v = Image.new('RGBA', img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(v)
    cx, cy = img.width / 2, img.height / 2
    max_r = math.sqrt(cx ** 2 + cy ** 2)
    steps = 30
    for i in range(steps, 0, -1):
        t = i / steps
        alpha = int(255 * strength * (1 - t ** 1.8))
        alpha = max(0, min(255, alpha))
        rx = int(cx * t * 1.3)
        ry = int(cy * t * 1.1)
        draw.ellipse([int(cx - rx), int(cy - ry), int(cx + rx), int(cy + ry)],
                     fill=(*color, alpha))
    return Image.alpha_composite(img, v)

def apply_shake(img, intensity, seed_offset=0):
    rng = random.Random(seed_offset)
    ox = rng.randint(-intensity, intensity)
    oy = rng.randint(-intensity, intensity)
    result = Image.new('RGBA', img.size, (0, 0, 0, 255))
    result.paste(img, (ox, oy))
    return result

def apply_chromatic_aberration(img, offset=1):
    r, g, b, a = img.split()
    r = r.transform(r.size, Image.AFFINE, (1, 0, offset, 0, 1, 0))
    b = b.transform(b.size, Image.AFFINE, (1, 0, -offset, 0, 1, 0))
    return Image.merge('RGBA', (r, g, b, a))

def crop_zoom(img, zoom, focus_x=None, focus_y=None):
    if focus_x is None: focus_x = img.width / 2
    if focus_y is None: focus_y = img.height / 2
    zw = int(img.width / zoom)
    zh = int(img.height / zoom)
    x1 = max(0, min(img.width - zw, int(focus_x - zw / 2)))
    y1 = max(0, min(img.height - zh, int(focus_y - zh / 2)))
    cropped = img.crop((x1, y1, x1 + zw, y1 + zh))
    return cropped.resize((img.width, img.height), Image.NEAREST)

def color_overlay(img, color, alpha):
    if alpha <= 0:
        return img
    ov = Image.new('RGBA', img.size, (*color, int(alpha)))
    return Image.alpha_composite(img, ov)

class ParticleSystem:
    def __init__(self, seed=42):
        self.particles = []
        self.rng = random.Random(seed)

    def emit(self, x, y, count, color, speed_range=(0.5, 2.0),
             life_range=(10, 30), size_range=(1, 3), gravity=0.0,
             spread=math.pi * 2, angle_offset=0, fade=True):
        for _ in range(count):
            angle = angle_offset + self.rng.uniform(-spread / 2, spread / 2)
            speed = self.rng.uniform(*speed_range)
            life = self.rng.randint(*life_range)
            size = self.rng.randint(*size_range)
            cr = max(0, min(255, color[0] + self.rng.randint(-15, 15)))
            cg = max(0, min(255, color[1] + self.rng.randint(-15, 15)))
            cb = max(0, min(255, color[2] + self.rng.randint(-15, 15)))
            self.particles.append({
                'x': float(x), 'y': float(y),
                'vx': math.cos(angle) * speed, 'vy': math.sin(angle) * speed,
                'life': life, 'max_life': life, 'size': size,
                'color': (cr, cg, cb), 'gravity': gravity, 'fade': fade,
            })

    def update(self):
        alive = []
        for p in self.particles:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['vy'] += p['gravity']
            p['life'] -= 1
            if p['life'] > 0:
                alive.append(p)
        self.particles = alive

    def draw(self, canvas):
        draw_ctx = ImageDraw.Draw(canvas)
        for p in self.particles:
            t = p['life'] / p['max_life'] if p['fade'] else 1.0
            alpha = int(255 * t)
            c = (*p['color'], alpha)
            s = p['size']
            x, y = int(p['x']), int(p['y'])
            if 0 <= x < W and 0 <= y < H:
                draw_ctx.rectangle([x, y, x + s, y + s], fill=c)

def get_font(size=8):
    for fp in [os.path.join(ASSETS, 'pixel_font.ttf'),
               'C:/Windows/Fonts/consola.ttf', 'C:/Windows/Fonts/lucon.ttf']:
        if os.path.exists(fp):
            try: return ImageFont.truetype(fp, size)
            except: pass
    return ImageFont.load_default()

def save_frame(img, scene_dir, frame_num):
    ensure_dir(scene_dir)
    if img.mode == 'RGBA':
        bg = Image.new('RGB', img.size, (0, 0, 0))
        bg.paste(img, mask=img.split()[3])
        img = bg
    img.save(os.path.join(scene_dir, f'frame_{frame_num:04d}.png'))


# ======================================================
# PROCEDURAL FALLBACKS (used when API assets missing)
# ======================================================

def proc_silhouette_run(pose=0):
    """Generate a running person silhouette procedurally."""
    img = Image.new('RGBA', (48, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    c = (12, 12, 12, 230)
    # Head
    draw.ellipse([18, 2, 30, 14], fill=c)
    # Torso
    draw.rectangle([20, 14, 28, 36], fill=c)
    # Different arm/leg poses
    if pose == 0:
        draw.line([(20, 18), (10, 30)], fill=c, width=3)
        draw.line([(28, 22), (38, 14)], fill=c, width=3)
        draw.line([(22, 36), (12, 56)], fill=c, width=3)
        draw.line([(26, 36), (38, 50)], fill=c, width=3)
    elif pose == 1:
        draw.line([(20, 20), (14, 14)], fill=c, width=3)
        draw.line([(28, 20), (36, 30)], fill=c, width=3)
        draw.line([(22, 36), (18, 56)], fill=c, width=3)
        draw.line([(26, 36), (30, 56)], fill=c, width=3)
    elif pose == 2:
        draw.line([(20, 22), (36, 16)], fill=c, width=3)
        draw.line([(28, 18), (12, 28)], fill=c, width=3)
        draw.line([(22, 36), (36, 52)], fill=c, width=3)
        draw.line([(26, 36), (14, 54)], fill=c, width=3)
    else:
        draw.line([(20, 20), (12, 16)], fill=c, width=3)
        draw.line([(28, 20), (34, 28)], fill=c, width=3)
        draw.line([(22, 36), (24, 56)], fill=c, width=3)
        draw.line([(26, 36), (22, 56)], fill=c, width=3)
    return img

def proc_boot(pose='kick'):
    img = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    c = (15, 15, 15, 255)
    if pose == 'windup':
        draw.rectangle([15, 20, 35, 50], fill=c)  # leg back
        draw.rectangle([10, 45, 38, 58], fill=c)   # sole
    elif pose == 'kick':
        draw.rectangle([10, 30, 55, 42], fill=c)   # leg extended
        draw.rectangle([45, 28, 62, 48], fill=c)    # boot tip
        draw.rectangle([45, 42, 62, 52], fill=c)    # sole
    else:  # follow_through
        draw.rectangle([10, 15, 45, 28], fill=c)    # leg up
        draw.rectangle([38, 10, 55, 32], fill=c)    # boot angled up
    return img


# ======================================================
# BACKGROUND RENDERER
# ======================================================

def load_or_render_bg(api_name, width=384, height=216, seed=42,
                       red_sky=False, panic=False, extra_wide=0):
    """Try to load PixelLab-generated bg, upscale it, add procedural details.
    Falls back to fully procedural if API image missing."""
    total_w = width + extra_wide

    # Try API background
    api_path = os.path.join(ASSETS, api_name)
    if os.path.exists(api_path) and os.path.getsize(api_path) > 500:
        base = Image.open(api_path).convert('RGBA')
        # Upscale from 128x72 to target size with nearest neighbor
        base = base.resize((total_w, height), Image.NEAREST)
    else:
        # Procedural fallback
        base = render_procedural_bg(total_w, height, seed, red_sky, panic)

    return base

def render_procedural_bg(width, height, seed=42, red_sky=False, panic=False):
    """Fully procedural junkyard background."""
    rng = random.Random(seed)
    img = Image.new('RGBA', (width, height), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)
    ground_y = int(height * 0.62)

    # Sky gradient
    if panic:
        sky_colors = [(25, 3, 3), (70, 12, 8), (120, 25, 10)]
    elif red_sky:
        sky_colors = [(35, 8, 8), (80, 18, 12), (130, 35, 15)]
    else:
        sky_colors = [(15, 12, 25), (30, 25, 40), (45, 38, 48)]

    for y in range(ground_y):
        t = y / ground_y
        idx = min(int(t * 2), 1)
        t2 = (t * 2) - idx
        r = int(lerp(sky_colors[idx][0], sky_colors[idx + 1][0], t2))
        g = int(lerp(sky_colors[idx][1], sky_colors[idx + 1][1], t2))
        b = int(lerp(sky_colors[idx][2], sky_colors[idx + 1][2], t2))
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

    # Mountains silhouette
    points = [(0, ground_y)]
    x = 0
    while x < width:
        x += rng.randint(15, 40)
        y = ground_y - rng.randint(5, 35)
        points.append((x, y))
    points.extend([(width, ground_y), (width, ground_y + 5), (0, ground_y + 5)])
    mc = (20, 18, 25, 255) if not red_sky else (40, 15, 12, 255)
    draw.polygon(points, fill=mc)

    # Ground
    for y in range(ground_y, height):
        depth = (y - ground_y) / max(1, height - ground_y)
        br = int(lerp(75, 45, depth))
        bg = int(lerp(58, 35, depth))
        bb = int(lerp(42, 25, depth))
        for x in range(width):
            n = rng.randint(-6, 6)
            draw.point((x, y), fill=(max(0, br + n), max(0, bg + n), max(0, bb + n), 255))

    # Scrap objects
    colors = [(110, 75, 45), (95, 65, 40), (75, 75, 80), (90, 88, 92)]
    for _ in range(15):
        sx = rng.randint(0, width)
        sy = rng.randint(ground_y - 5, height - 15)
        sw = rng.randint(8, 30)
        sh = rng.randint(5, 25)
        c = rng.choice(colors)
        draw.rectangle([sx, sy, sx + sw, sy + sh], fill=(*c, 255),
                       outline=(c[0]//2, c[1]//2, c[2]//2, 255))

    # Clouds
    for _ in range(5):
        cx = rng.randint(0, width)
        cy = rng.randint(5, ground_y // 3)
        cw = rng.randint(30, 70)
        ch = rng.randint(6, 12)
        cc = (30, 25, 35, 45) if not red_sky else (60, 20, 12, 60)
        draw.ellipse([cx - cw//2, cy - ch//2, cx + cw//2, cy + ch//2], fill=cc)

    return img

def composite_junk_props(bg, seed=42, count=5):
    """Layer PixelLab-generated junk props onto background."""
    rng = random.Random(seed)
    prop_names = ['junk_barrel.png', 'junk_pipe.png', 'junk_gear.png',
                  'junk_pile.png', 'junk_crane.png']
    ground_y = int(bg.height * 0.62)
    result = bg.copy()

    for _ in range(count):
        name = rng.choice(prop_names)
        prop = load_asset(name)
        if prop.width > 4 and prop.height > 4:
            # Scale to fit scene
            scale = rng.uniform(0.4, 1.0)
            pw = max(4, int(prop.width * scale))
            ph = max(4, int(prop.height * scale))
            prop = prop.resize((pw, ph), Image.NEAREST)
            px = rng.randint(-10, bg.width - pw + 10)
            py_min = ground_y - 10
            py_max = max(py_min, bg.height - ph)
            py = rng.randint(py_min, py_max)
            paste_alpha(result, prop, px, py)

    return result


# ======================================================
# ANIMATED SILHOUETTE RUNNERS
# ======================================================

class AnimatedRunner:
    """An animated running silhouette person with walk cycle."""
    def __init__(self, x, y, speed, direction, scale, rng):
        self.x = x
        self.y = y
        self.speed = speed
        self.direction = direction  # -1 or 1
        self.scale = scale
        self.frame_offset = rng.randint(0, 100)

        # Load 4 pose frames (API or procedural)
        self.frames = []
        for i in range(4):
            api_frame = load_asset(f'sil_run_{i+1}.png')
            if api_frame.width > 4:
                frame = api_frame
            else:
                frame = proc_silhouette_run(i)
            # Scale
            fw = max(4, int(frame.width * scale))
            fh = max(4, int(frame.height * scale))
            frame = frame.resize((fw, fh), Image.NEAREST)
            if direction > 0:
                frame = frame.transpose(Image.FLIP_LEFT_RIGHT)
            self.frames.append(frame)

    def draw_at_frame(self, canvas, frame_num):
        # Animate position
        cx = self.x + frame_num * self.speed * self.direction
        # Wrap around
        cx = (cx + 80) % (W + 160) - 80
        # Pick animation frame (change every 4 render frames)
        anim_idx = ((frame_num + self.frame_offset) // 4) % 4
        sprite = self.frames[anim_idx]
        paste_centered(canvas, sprite, int(cx), int(self.y))


# ======================================================
# ANIMATED BOOT
# ======================================================

class AnimatedBoot:
    """Boot with wind-up, kick, and follow-through animation."""
    def __init__(self):
        self.poses = {}
        for pose_name in ['windup', 'kick', 'follow_through']:
            api_name = f'boot_{pose_name.replace("_", "_")}.png'
            api_name_map = {
                'windup': 'boot_wind_up.png',
                'kick': 'boot_kick.png',
                'follow_through': 'boot_follow_through.png'
            }
            frame = load_asset(api_name_map[pose_name])
            if frame.width <= 4:
                frame = proc_boot(pose_name)
            frame = frame.resize((64, 64), Image.NEAREST)
            self.poses[pose_name] = frame

    def get_frame(self, t):
        """t: 0-1 through the kick animation. Returns (image, x_offset, y_offset)."""
        if t < 0.3:
            # Wind up - pull back
            bt = t / 0.3
            x = int(lerp(-80, -20, ease_out(bt)))
            y = H - 80
            return self.poses['windup'], x, y
        elif t < 0.5:
            # Kick forward - fast
            bt = (t - 0.3) / 0.2
            x = int(lerp(-20, W // 2 - 40, ease_out(bt)))
            y = H - 78
            return self.poses['kick'], x, y
        elif t < 0.7:
            # Follow through
            bt = (t - 0.5) / 0.2
            x = int(lerp(W // 2 - 40, W // 2 - 20, bt))
            y = H - 82
            return self.poses['follow_through'], x, y
        else:
            # Retract
            bt = (t - 0.7) / 0.3
            x = int(lerp(W // 2 - 20, -80, ease_in(bt)))
            y = H - 80
            return self.poses['follow_through'], x, y


# ======================================================
# SCENE RENDERERS - Extended timing
# ======================================================

def render_scene1():
    """Scene 1 (0-5s): The Junkyard - establishing shot, slow pan, dog trots."""
    print('  Rendering Scene 1: The Junkyard (5s)...')
    scene_dir = os.path.join(SCENES, 'scene1')
    total_frames = 5 * FPS  # 120 frames

    # Build rich background with API bg + props
    bg_base = load_or_render_bg('bg_junkyard_1.png', W, H, seed=101, extra_wide=200)
    bg = composite_junk_props(bg_base, seed=201, count=8)
    pan_range = bg.width - W

    run_e = load_anim_sequence('base', 'run', 'east')
    dust = load_asset('dust_cloud.png')
    if dust.width > 4:
        dust = dust.resize((16, 16), Image.NEAREST)

    particles = ParticleSystem(seed=77)

    for f in range(total_frames):
        t = f / total_frames

        # First 1s: static establishing shot, then pan begins
        if t < 0.15:
            pan = 0
        else:
            pan_t = (t - 0.15) / 0.85
            pan = int(ease_in_out(pan_t) * pan_range * 0.9)

        canvas = bg.crop((pan, 0, pan + W, H)).copy()

        # Dog enters at 0.5s, walks across
        dog_appear = 0.1
        if t > dog_appear:
            dog_t = (t - dog_appear) / (1 - dog_appear)
            dog_x = int(lerp(-40, W * 0.7, ease_in_out(dog_t * 0.85)))
            dog_y = H - 52

            # Animate at pixel-art speed (every 3rd frame)
            anim_idx = (f // 3) % len(run_e)
            sprite = run_e[anim_idx]
            paste_centered(canvas, sprite, dog_x, dog_y)

            # Dust puffs behind dog
            if f % 5 == 0 and 10 < dog_x < W - 10:
                particles.emit(dog_x - 18, dog_y + 38, 4,
                              color=(85, 70, 55), speed_range=(0.2, 1.0),
                              life_range=(10, 25), size_range=(1, 3),
                              gravity=0.02, spread=math.pi * 0.5, angle_offset=-math.pi * 0.6)

        # Ambient floating dust
        if f % 12 == 0:
            particles.emit(random.randint(0, W), random.randint(H//2, H), 1,
                          color=(75, 65, 55), speed_range=(0.05, 0.2),
                          life_range=(30, 50), size_range=(1, 1), gravity=-0.01)

        particles.update()
        particles.draw(canvas)

        # Color grade: warm, slightly desaturated
        enhancer = ImageEnhance.Color(canvas)
        canvas = enhancer.enhance(0.75)
        canvas = apply_vignette(canvas, strength=0.35)

        save_frame(canvas, scene_dir, f)

    print(f'    -> {total_frames} frames')


def render_scene2():
    """Scene 2 (5-8s): Kicked away - boot winds up, kicks can, dog flinches."""
    print('  Rendering Scene 2: Ignored / Kicked Away (3s)...')
    scene_dir = os.path.join(SCENES, 'scene2')
    total_frames = 3 * FPS  # 72 frames

    bg = load_or_render_bg('bg_junkyard_2.png', W, H, seed=102)
    bg = composite_junk_props(bg, seed=202, count=4)

    boot = AnimatedBoot()
    can = load_asset('tin_can.png')
    if can.width <= 4:
        can = Image.new('RGBA', (14, 14), (140, 110, 80, 255))
    can = can.resize((14, 14), Image.NEAREST)

    idle_e = load_anim_sequence('base', 'idle', 'east')
    idle_s = load_anim_sequence('base', 'idle', 'south')
    jump_sw = load_anim_sequence('base', 'jump', 'south-west')
    particles = ParticleSystem(seed=88)

    dog_x = W // 2 + 50
    dog_y = H - 52

    for f in range(total_frames):
        t = f / total_frames
        canvas = bg.copy()

        # --- BOOT ANIMATION (0-0.6) ---
        if t < 0.6:
            boot_img, bx, by = boot.get_frame(t / 0.6)
            paste_alpha(canvas, boot_img, bx, by)

        # --- CAN (launched at t=0.25, flies to dog) ---
        kick_t = 0.25
        can_land_t = 0.55
        if kick_t < t < can_land_t + 0.15:
            if t < can_land_t:
                ct = (t - kick_t) / (can_land_t - kick_t)
                can_x = int(lerp(W // 2 - 30, dog_x - 10, ct))
                can_y = int(H - 45 - 40 * math.sin(ct * math.pi))
                rotation = int(ct * 720) % 360
                can_rot = can.rotate(rotation, expand=False, resample=Image.NEAREST)
                paste_centered(canvas, can_rot, can_x, can_y)
            else:
                # Bouncing on ground
                bounce_t = (t - can_land_t) / 0.15
                bounce_h = int(8 * math.sin(bounce_t * math.pi * 2.5) * (1 - bounce_t))
                paste_centered(canvas, can, dog_x - 10, H - 38 - max(0, bounce_h))

            # Kick impact sparks
            if abs(t - kick_t) < 0.02:
                particles.emit(W // 2 - 25, H - 50, 12,
                              color=(180, 150, 100), speed_range=(1, 4),
                              life_range=(5, 15), size_range=(1, 2), gravity=0.1,
                              spread=math.pi * 0.8, angle_offset=-math.pi / 3)
        elif t >= can_land_t + 0.15:
            # Can at rest
            paste_centered(canvas, can, dog_x - 10, H - 38)

        # --- DOG ---
        if t < 0.35:
            # Idle, looking east (toward boot approach)
            sprite = idle_e[(f // 5) % len(idle_e)]
            paste_centered(canvas, sprite, dog_x, dog_y)
        elif t < 0.55:
            # Notices can coming, turns south
            sprite = idle_s[(f // 4) % len(idle_s)]
            paste_centered(canvas, sprite, dog_x, dog_y)
        elif t < 0.75:
            # FLINCH - jump back
            flinch_t = min(1, (t - 0.55) / 0.15)
            idx = min(int(flinch_t * len(jump_sw)), len(jump_sw) - 1)
            sprite = jump_sw[idx]
            recoil_x = int(12 * math.sin(flinch_t * math.pi))
            recoil_y = int(-6 * math.sin(flinch_t * math.pi))
            paste_centered(canvas, sprite, dog_x + recoil_x, dog_y + recoil_y)

            # Dust on landing
            if abs(flinch_t - 0.8) < 0.1:
                particles.emit(dog_x + 10, dog_y + 40, 6,
                              color=(80, 65, 50), speed_range=(0.3, 1.5),
                              life_range=(8, 18), size_range=(1, 2), gravity=0.05)
        else:
            # Cowers, looks down
            sprite = idle_s[(f // 6) % len(idle_s)]
            droop = int(3 * ease_in_out((t - 0.75) / 0.25))
            paste_centered(canvas, sprite, dog_x + 5, dog_y + droop)

        particles.update()
        particles.draw(canvas)

        enhancer = ImageEnhance.Color(canvas)
        canvas = enhancer.enhance(0.7)
        canvas = apply_vignette(canvas, strength=0.4)

        save_frame(canvas, scene_dir, f)

    print(f'    -> {total_frames} frames')


def render_scene3():
    """Scene 3 (8-11s): Rock bottom - alone, dark, slow zoom."""
    print('  Rendering Scene 3: Rock Bottom (3s)...')
    scene_dir = os.path.join(SCENES, 'scene3')
    total_frames = 3 * FPS  # 72 frames

    bg = load_or_render_bg('bg_junkyard_night.png', W, H, seed=103)
    idle_s = load_anim_sequence('base', 'idle', 'south')
    particles = ParticleSystem(seed=33)

    dog_x = W // 2
    dog_y = H - 52

    for f in range(total_frames):
        t = f / total_frames
        canvas = bg.copy()

        # Dog: very slow idle, subtle breathing
        sprite = idle_s[(f // 8) % len(idle_s)]  # Very slow animation
        droop = int(2 * math.sin(t * math.pi * 1.5))
        paste_centered(canvas, sprite, dog_x, dog_y + droop)

        # Floating dust motes (lonely atmosphere)
        if f % 10 == 0:
            particles.emit(random.randint(0, W), random.randint(40, H - 20), 1,
                          color=(60, 55, 50), speed_range=(0.05, 0.15),
                          life_range=(30, 60), size_range=(1, 1), gravity=-0.005,
                          fade=True)

        particles.update()
        particles.draw(canvas)

        # Slow zoom
        zoom = lerp(1.0, 1.2, ease_in_out(t))
        canvas = crop_zoom(canvas, zoom, dog_x, dog_y - 10)

        # Heavy mood: dark, desaturated, strong vignette
        canvas = apply_vignette(canvas, strength=0.8)
        enhancer = ImageEnhance.Color(canvas)
        canvas = enhancer.enhance(0.3)
        enhancer = ImageEnhance.Brightness(canvas)
        canvas = enhancer.enhance(0.65)

        save_frame(canvas, scene_dir, f)

    print(f'    -> {total_frames} frames')


def render_scene4():
    """Scene 4 (11-15s): The Rumble - escalating earthquake."""
    print('  Rendering Scene 4: The Rumble (4s)...')
    scene_dir = os.path.join(SCENES, 'scene4')
    total_frames = 4 * FPS  # 96 frames

    bg = load_or_render_bg('bg_red_sky.png', W, H, seed=104, red_sky=True)
    bg = composite_junk_props(bg, seed=204, count=4)

    crack1 = load_asset('ground_crack_1.png')
    crack2 = load_asset('ground_crack_2.png')
    if crack1.width <= 4:
        crack1 = Image.new('RGBA', (96, 48), (0, 0, 0, 0))
        d = ImageDraw.Draw(crack1)
        d.line([(0, 24), (30, 20), (50, 28), (80, 22), (96, 26)], fill=(20, 15, 10, 255), width=2)
    if crack2.width <= 4:
        crack2 = crack1.copy()
    crack1 = crack1.resize((120, 40), Image.NEAREST)
    crack2 = crack2.resize((100, 35), Image.NEAREST)

    debris_imgs = []
    for dname in ['debris_rock_1.png', 'debris_rock_2.png', 'debris_metal.png']:
        d = load_asset(dname)
        if d.width > 4:
            debris_imgs.append(d.resize((12, 12), Image.NEAREST))

    idle_s = load_anim_sequence('base', 'idle', 'south')
    bark_s = load_anim_sequence('base', 'bark', 'south')
    idle_e = load_anim_sequence('base', 'idle', 'east')
    idle_w = load_anim_sequence('base', 'idle', 'west')
    particles = ParticleSystem(seed=44)

    dog_x = W // 2
    dog_y = H - 52

    for f in range(total_frames):
        t = f / total_frames
        canvas = bg.copy()

        # -- Growing red/orange glow from below --
        glow_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow_layer)
        glow_str = lerp(15, 200, ease_in(t))
        for y in range(H - 55, H):
            yt = (y - (H - 55)) / 55
            alpha = int(glow_str * yt * yt)
            gd.line([(0, y), (W, y)], fill=(220, 70, 20, min(255, alpha)))
        canvas = Image.alpha_composite(canvas, glow_layer)

        # -- Ground cracks appear progressively --
        crack_data = [(70, H - 38, 0.2, crack1), (200, H - 35, 0.35, crack2),
                      (300, H - 40, 0.5, crack1)]
        for cx, cy, start, crack_img in crack_data:
            if t > start:
                ct = min(1, (t - start) / 0.25)
                visible_w = int(crack_img.width * ease_out(ct))
                if visible_w > 4:
                    cropped = crack_img.crop((0, 0, visible_w, crack_img.height))
                    paste_alpha(canvas, cropped, cx - visible_w // 2, cy - cropped.height // 2)

        # -- Dog reacts: idle -> looks around -> barks --
        if t < 0.25:
            sprite = idle_s[(f // 5) % len(idle_s)]
        elif t < 0.45:
            # Looks left and right nervously
            look_cycle = int((t - 0.25) / 0.05) % 4
            if look_cycle < 2:
                sprite = idle_e[(f // 3) % len(idle_e)]
            else:
                sprite = idle_w[(f // 3) % len(idle_w)]
        else:
            sprite = bark_s[(f // 3) % len(bark_s)]

        paste_centered(canvas, sprite, dog_x, dog_y)

        # -- Debris falling from sky, increasing density --
        emit_rate = max(1, int(8 - 7 * t))
        if f % emit_rate == 0:
            count = int(1 + 4 * t)
            particles.emit(random.randint(0, W), -5, count,
                          color=(95, 70, 45), speed_range=(0.5, 3.0),
                          life_range=(18, 40), size_range=(1, 4),
                          gravity=0.15, spread=math.pi * 0.4, angle_offset=math.pi / 2)

        # Sprite-based debris
        if debris_imgs and f % max(1, int(5 - 4*t)) == 0:
            di = random.choice(debris_imgs)
            dx = random.randint(0, W)
            dy = random.randint(-20, H // 2)
            paste_centered(canvas, di, dx, dy)

        # Embers rising from ground glow
        if f % 3 == 0 and t > 0.2:
            particles.emit(random.randint(0, W), H + 2, int(3 * t),
                          color=(230, 120, 40), speed_range=(0.3, 1.5),
                          life_range=(12, 28), size_range=(1, 2),
                          gravity=-0.08, spread=math.pi * 0.3, angle_offset=-math.pi / 2)

        particles.update()
        particles.draw(canvas)

        # -- Screen shake: builds --
        shake = int(lerp(0, 6, ease_in(t)))
        if shake > 0:
            canvas = apply_shake(canvas, shake, seed_offset=f)

        # Red tint
        canvas = color_overlay(canvas, (160, 30, 10), lerp(0, 50, t))

        # Chromatic aberration in last third
        if t > 0.65:
            canvas = apply_chromatic_aberration(canvas, offset=int(1 + (t - 0.65) * 8))

        canvas = apply_vignette(canvas, strength=0.45, color=(60, 10, 5))

        save_frame(canvas, scene_dir, f)

    print(f'    -> {total_frames} frames')


def render_scene5_bookends():
    """Scene 5 (15-18s): 3s external slot + 0.5s artifact landing overlay."""
    print('  Rendering Scene 5 overlay: Artifact landing (0.5s)...')
    scene_dir = os.path.join(SCENES, 'scene5_overlay')
    overlay_frames = int(0.5 * FPS)

    artifact = load_asset('artifact_glow.png')
    if artifact.width <= 4:
        artifact = Image.new('RGBA', (20, 20), (100, 220, 240, 255))
    artifact = artifact.resize((22, 22), Image.NEAREST)
    particles = ParticleSystem(seed=55)

    for f in range(overlay_frames):
        t = f / overlay_frames
        canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))

        # Artifact tumbles from upper-right to lower-center
        art_x = int(lerp(W * 0.7, W // 2 + 12, ease_in_out(t)))
        art_y = int(lerp(20, H - 42, t ** 1.5))

        # Trail particles
        if f % 2 == 0:
            particles.emit(art_x, art_y, 4,
                          color=(80, 200, 220), speed_range=(0.2, 1.0),
                          life_range=(6, 16), size_range=(1, 2), gravity=0.0)
            particles.emit(art_x, art_y, 2,
                          color=(200, 180, 60), speed_range=(0.2, 0.8),
                          life_range=(4, 12), size_range=(1, 1))

        particles.update()
        particles.draw(canvas)

        # Glow
        glow = create_glow((40, 200, 220), 20, 0.7)
        paste_centered(canvas, glow, art_x, art_y)
        glow2 = create_glow((200, 170, 50), 14, 0.4)
        paste_centered(canvas, glow2, art_x, art_y)

        # Spinning artifact
        rotation = int(t * 1080) % 360
        art_rot = artifact.rotate(rotation, expand=False, resample=Image.NEAREST)
        paste_centered(canvas, art_rot, art_x, art_y)

        # Landing flash
        if t > 0.85:
            flash_t = (t - 0.85) / 0.15
            canvas = color_overlay(canvas, (200, 240, 255), flash_t * 140)

        save_frame(canvas, scene_dir, f)

    print(f'    -> {overlay_frames} frames')


def render_scene6():
    """Scene 6 (18-21s): The Artifact - discovery, approach, touch, FLASH."""
    print('  Rendering Scene 6: The Artifact (3s)...')
    scene_dir = os.path.join(SCENES, 'scene6')
    total_frames = 3 * FPS  # 72 frames

    bg = load_or_render_bg('bg_junkyard_night.png', W, H, seed=106)

    artifact = load_asset('artifact_large.png')
    if artifact.width <= 4:
        artifact = Image.new('RGBA', (28, 28), (100, 220, 240, 255))
    artifact = artifact.resize((30, 30), Image.NEAREST)

    magic_burst = load_asset('magic_burst_large.png')
    if magic_burst.width <= 4:
        magic_burst = None

    idle_s = load_anim_sequence('base', 'idle', 'south')
    idle_se = load_anim_sequence('base', 'idle', 'south-east')
    run_e = load_anim_sequence('base', 'run', 'east')
    bark_s = load_anim_sequence('base', 'bark', 'south')
    particles = ParticleSystem(seed=66)

    dog_start_x = W // 2 - 60
    dog_y = H - 52
    art_x = W // 2 + 20
    art_y = H - 32

    for f in range(total_frames):
        t = f / total_frames
        canvas = bg.copy()

        # -- Artifact pulsing glow (always visible) --
        pulse = 0.5 + 0.5 * math.sin(f * 0.35)
        glow = create_glow((40, 200, 220), int(35 * pulse), 0.5 * pulse)
        paste_centered(canvas, glow, art_x, art_y)
        glow2 = create_glow((180, 160, 50), int(22 * pulse), 0.25 * pulse)
        paste_centered(canvas, glow2, art_x, art_y)

        # Sparkles around artifact
        if f % 4 == 0:
            particles.emit(art_x + random.randint(-12, 12), art_y + random.randint(-8, 4), 2,
                          color=(100, 220, 240), speed_range=(0.15, 0.5),
                          life_range=(10, 20), size_range=(1, 1), gravity=-0.04)

        paste_centered(canvas, artifact, art_x, art_y)

        # -- PHASE 1 (0-0.25): Dog notices, walks toward artifact --
        if t < 0.25:
            walk_t = ease_in_out(t / 0.25)
            dog_x = int(lerp(dog_start_x, art_x - 35, walk_t))
            sprite = run_e[(f // 4) % len(run_e)]
            paste_centered(canvas, sprite, dog_x, dog_y)

        # -- PHASE 2 (0.25-0.4): Dog stops, looks at artifact --
        elif t < 0.4:
            dog_x = art_x - 35
            sprite = idle_se[(f // 6) % len(idle_se)]
            paste_centered(canvas, sprite, dog_x, dog_y)

        # -- PHASE 3 (0.4-0.55): Dog cautiously leans toward artifact --
        elif t < 0.55:
            dog_x = art_x - 35
            reach_t = ease_in_out((t - 0.4) / 0.15)
            lean_x = int(reach_t * 14)
            lean_y = int(reach_t * 5)
            sprite = idle_se[0]
            paste_centered(canvas, sprite, dog_x + lean_x, dog_y + lean_y)

        # -- PHASE 4 (0.55-0.72): TOUCH! Magic explosion --
        elif t < 0.72:
            dog_x = art_x - 35
            flash_t = (t - 0.55) / 0.17

            # Magic burst expanding
            burst_r = int(lerp(10, 200, ease_out(flash_t)))
            burst = create_glow((180, 240, 255), burst_r, lerp(1.0, 0.15, flash_t))
            paste_centered(canvas, burst, art_x, art_y)

            # Second ring
            ring_r = int(lerp(5, 140, ease_out(flash_t)))
            ring = create_glow((255, 255, 255), ring_r, lerp(0.9, 0.0, flash_t))
            paste_centered(canvas, ring, art_x, art_y)

            # If we have the API burst sprite, layer it
            if magic_burst is not None:
                mb_size = int(lerp(30, 280, ease_out(flash_t)))
                mb = magic_burst.resize((mb_size, mb_size), Image.NEAREST)
                mb_alpha = int(lerp(220, 0, flash_t))
                r, g, b, a = mb.split()
                a = a.point(lambda x: min(x, mb_alpha))
                mb = Image.merge('RGBA', (r, g, b, a))
                paste_centered(canvas, mb, art_x, art_y)

            # Explosion particles
            if f == int(0.55 * total_frames):
                particles.emit(art_x, art_y, 60,
                              color=(150, 230, 255), speed_range=(2, 7),
                              life_range=(10, 30), size_range=(1, 3), gravity=0.0)
                particles.emit(art_x, art_y, 30,
                              color=(255, 220, 100), speed_range=(1, 4),
                              life_range=(8, 20), size_range=(1, 2))

            # White flash
            flash_alpha = int(lerp(240, 0, ease_out(flash_t)))
            canvas = color_overlay(canvas, (220, 240, 255), flash_alpha)

            # Dog recoils
            sprite = bark_s[min(int(flash_t * len(bark_s)), len(bark_s) - 1)]
            recoil = int(18 * math.sin(flash_t * math.pi) * (1 - flash_t))
            paste_centered(canvas, sprite, dog_x - recoil, dog_y - int(recoil * 0.4))

            if flash_t < 0.5:
                canvas = apply_chromatic_aberration(canvas, offset=int(3 * (1 - flash_t * 2)))

        # -- PHASE 5 (0.72-1.0): Dog amazed, residual glow --
        else:
            dog_x = art_x - 35
            residual_t = (t - 0.72) / 0.28

            glow_r = create_glow((80, 200, 220), 55, lerp(0.5, 0.25, residual_t))
            paste_centered(canvas, glow_r, art_x, art_y)
            paste_centered(canvas, artifact, art_x, art_y)

            sprite = bark_s[(f // 5) % len(bark_s)]
            paste_centered(canvas, sprite, dog_x, dog_y)

            # Residual magic sparkles drifting
            if f % 3 == 0:
                particles.emit(art_x + random.randint(-20, 20),
                              art_y + random.randint(-20, 10), 3,
                              color=(120, 220, 240), speed_range=(0.1, 0.4),
                              life_range=(12, 25), size_range=(1, 1), gravity=-0.03)

        particles.update()
        particles.draw(canvas)

        # Slow zoom
        zoom = lerp(1.0, 1.1, ease_in_out(t))
        canvas = crop_zoom(canvas, zoom, (art_x + dog_x) / 2 if t < 0.55 else art_x, dog_y)

        canvas = apply_vignette(canvas, strength=0.45, color=(10, 25, 35))

        save_frame(canvas, scene_dir, f)

    print(f'    -> {total_frames} frames')


def render_scene7():
    """Scene 7 (21-24s): Everyone runs, hero awakens."""
    print('  Rendering Scene 7: Hero Awakens (3s)...')
    scene_dir = os.path.join(SCENES, 'scene7')
    total_frames = 3 * FPS  # 72 frames

    bg = load_or_render_bg('bg_catastrophe.png', W, H, seed=107, panic=True)

    artifact = load_asset('artifact_large.png')
    if artifact.width <= 4:
        artifact = Image.new('RGBA', (20, 20), (100, 220, 240, 255))
    artifact = artifact.resize((22, 22), Image.NEAREST)

    idle_s = load_anim_sequence('base', 'idle', 'south')
    particles = ParticleSystem(seed=77)

    # Create animated runners
    rng = random.Random(300)
    runners = []
    for _ in range(12):
        rx = rng.randint(-60, W + 60)
        ry = rng.randint(H - 90, H - 45)
        speed = rng.uniform(2.5, 5.5)
        dirn = rng.choice([-1, 1])
        scale = rng.uniform(0.5, 1.1)
        runners.append(AnimatedRunner(rx, ry, speed, dirn, scale, rng))

    dog_x = W // 2
    dog_y = H - 52

    for f in range(total_frames):
        t = f / total_frames
        canvas = bg.copy()

        # Red sky pulse
        pulse = 25 + int(15 * math.sin(f * 0.4))
        canvas = color_overlay(canvas, (140, 25, 10), pulse)

        # -- Falling debris --
        if f % 2 == 0:
            particles.emit(random.randint(0, W), -8, 4,
                          color=(90, 65, 45), speed_range=(1, 3.5),
                          life_range=(20, 45), size_range=(1, 5),
                          gravity=0.12, spread=math.pi * 0.3, angle_offset=math.pi / 2)
        # Rising embers
        if f % 3 == 0:
            particles.emit(random.randint(0, W), H + 3, 3,
                          color=(235, 130, 50), speed_range=(0.3, 1.2),
                          life_range=(15, 35), size_range=(1, 2), gravity=-0.06)

        # -- Animated running silhouettes --
        for runner in runners:
            runner.draw_at_frame(canvas, f)

        # -- Dog standing firm, artifact glowing --
        glow_i = lerp(0.3, 0.95, ease_in_out(t))
        glow_cyan = create_glow((60, 200, 220), 40, glow_i)
        glow_gold = create_glow((220, 180, 50), 30, glow_i * 0.6)
        paste_centered(canvas, glow_gold, dog_x, dog_y + 14)
        paste_centered(canvas, glow_cyan, dog_x, dog_y + 10)
        paste_centered(canvas, artifact, dog_x + 2, dog_y + 20)

        # Magic particles emanating from artifact
        if f % 2 == 0:
            particles.emit(dog_x, dog_y + 18, 2,
                          color=(100, 210, 230), speed_range=(0.3, 1.0),
                          life_range=(8, 18), size_range=(1, 2), gravity=-0.05)

        sprite = idle_s[(f // 6) % len(idle_s)]
        paste_centered(canvas, sprite, dog_x, dog_y)

        particles.update()
        particles.draw(canvas)

        # Slow zoom to dog's face
        zoom = lerp(1.0, 1.4, ease_in_out(t))
        canvas = crop_zoom(canvas, zoom, dog_x, dog_y - 18)

        # Warm golden + cyan bloom
        bloom_a = int(lerp(5, 40, t))
        canvas = color_overlay(canvas, (180, 165, 90), bloom_a)

        canvas = apply_vignette(canvas, strength=0.5, color=(40, 10, 5))

        save_frame(canvas, scene_dir, f)

    print(f'    -> {total_frames} frames')


def render_scene8():
    """Scene 8 (24-26s): Tagline card."""
    print('  Rendering Scene 8: Tagline Card (2s)...')
    scene_dir = os.path.join(SCENES, 'scene8')
    total_frames = 2 * FPS  # 48 frames

    font = get_font(10)
    tagline = "The right equipment changes everything."
    particles = ParticleSystem(seed=88)

    # Pre-spawn
    for _ in range(50):
        particles.emit(random.randint(0, W), random.randint(0, H), 1,
                      color=(70, 180, 200), speed_range=(0.05, 0.25),
                      life_range=(40, 80), size_range=(1, 2), gravity=-0.008, fade=True)

    for f in range(total_frames):
        t = f / total_frames
        canvas = Image.new('RGBA', (W, H), (8, 6, 14, 255))
        draw = ImageDraw.Draw(canvas)

        # Subtle bg gradient
        for y in range(H):
            yt = y / H
            v = int(8 * math.sin(yt * math.pi))
            draw.line([(0, y), (W, y)], fill=(8 + v, 6 + v // 2, 14 + v, 255))

        particles.update()
        if f % 3 == 0:
            particles.emit(random.randint(0, W), random.randint(0, H), 1,
                          color=(60 + random.randint(0, 40), 170 + random.randint(0, 40), 190 + random.randint(0, 40)),
                          speed_range=(0.05, 0.2), life_range=(20, 40), size_range=(1, 1),
                          gravity=-0.008, fade=True)
        particles.draw(canvas)

        # Text fade in (0-0.3), hold, fade out (0.85-1)
        if t < 0.3:
            text_alpha = int(ease_out(t / 0.3) * 255)
        elif t > 0.85:
            text_alpha = int(lerp(255, 0, (t - 0.85) / 0.15))
        else:
            text_alpha = 255

        bbox = draw.textbbox((0, 0), tagline, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = (W - tw) // 2
        ty = (H - th) // 2

        # Text glow
        if text_alpha > 30:
            glow_text = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            gd = ImageDraw.Draw(glow_text)
            gd.text((tx, ty), tagline, fill=(80, 200, 220, text_alpha // 3), font=font)
            glow_text = glow_text.filter(ImageFilter.GaussianBlur(radius=3))
            canvas = Image.alpha_composite(canvas, glow_text)

        draw = ImageDraw.Draw(canvas)
        draw.text((tx, ty), tagline, fill=(210, 215, 225, text_alpha), font=font)

        canvas = apply_vignette(canvas, strength=0.3)
        save_frame(canvas, scene_dir, f)

    print(f'    -> {total_frames} frames')


def render_scene9():
    """Scene 9 (26-28s): Title card - SCRAPWRIGHT slams in."""
    print('  Rendering Scene 9: Title Card (2s)...')
    scene_dir = os.path.join(SCENES, 'scene9')
    total_frames = 2 * FPS  # 48 frames

    font_large = get_font(22)
    title = "SCRAPWRIGHT"
    particles = ParticleSystem(seed=99)

    slam_frame = 5

    for f in range(total_frames):
        t = f / total_frames
        canvas = Image.new('RGBA', (W, H), (0, 0, 0, 255))
        draw = ImageDraw.Draw(canvas)

        bbox = draw.textbbox((0, 0), title, font=font_large)
        tw = bbox[2] - bbox[0]
        tx = (W - tw) // 2
        ty = H // 2 - 14

        if f < slam_frame:
            # Anticipation: pure black
            pass

        elif f == slam_frame:
            # SLAM: full white flash
            canvas = Image.new('RGBA', (W, H), (255, 255, 255, 255))
            draw = ImageDraw.Draw(canvas)
            draw.text((tx, ty), title, fill=(0, 0, 0, 255), font=font_large)
            particles.emit(W // 2, ty + 12, 60,
                          color=(200, 220, 255), speed_range=(2, 7),
                          life_range=(8, 22), size_range=(1, 3), gravity=0.1)

        elif f < slam_frame + 8:
            # Flash fading + shake
            flash_t = (f - slam_frame) / 8
            draw.text((tx, ty), title, fill=(255, 255, 255, 255), font=font_large)
            flash_a = int(lerp(220, 0, ease_out(flash_t)))
            canvas = color_overlay(canvas, (255, 255, 255), flash_a)
            shake_i = max(1, int(5 * (1 - flash_t)))
            canvas = apply_shake(canvas, shake_i, seed_offset=f)
            if flash_t < 0.6:
                canvas = apply_chromatic_aberration(canvas, offset=int(3 * (1 - flash_t)))

        elif f < total_frames - FPS // 2:
            # Title hold with glow pulse
            glow_pulse = 0.15 + 0.1 * math.sin(f * 0.25)
            glow_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            gd = ImageDraw.Draw(glow_layer)
            gd.text((tx, ty), title, fill=(80, 200, 220, int(255 * glow_pulse)), font=font_large)
            glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=4))
            canvas = Image.alpha_composite(canvas, glow_layer)
            draw = ImageDraw.Draw(canvas)
            draw.text((tx, ty), title, fill=(255, 255, 255, 255), font=font_large)

        else:
            # Fade out
            fade_t = (f - (total_frames - FPS // 2)) / (FPS // 2)
            text_alpha = int(lerp(255, 0, ease_in(fade_t)))
            draw.text((tx, ty), title, fill=(255, 255, 255, text_alpha), font=font_large)

        particles.update()
        particles.draw(canvas)
        save_frame(canvas, scene_dir, f)

    print(f'    -> {total_frames} frames')


# ======================================================
# FFMPEG ASSEMBLY
# ======================================================

def build_ffmpeg_script():
    bat = os.path.join(ROOT, 'assemble.bat')
    scenes_info = [
        ('scene1', 5), ('scene2', 3), ('scene3', 3), ('scene4', 4),
        ('scene6', 3), ('scene7', 3), ('scene8', 2), ('scene9', 2),
    ]

    lines = ['@echo off', 'REM Scrapwright Intro - Video Assembly v3', f'cd /d "{ROOT}"', '']

    for name, _ in scenes_info:
        lines.append(f'echo Encoding {name}...')
        lines.append(f'ffmpeg -y -framerate {FPS} -i "scenes\\{name}\\frame_%%04d.png" '
                     f'-c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\\{name}.mp4" 2>nul')
    lines.append('')

    lines.append('REM Scene 5 (external clip)')
    lines.append(f'if exist "scenes\\scene5_cataclysm.mp4" (')
    lines.append(f'  echo Processing Scene 5...')
    lines.append(f'  ffmpeg -y -i "scenes\\scene5_cataclysm.mp4" '
                 f'-vf "scale={W}:{H}:flags=neighbor,fps={FPS}" '
                 f'-t 3 -c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\\scene5_scaled.mp4" 2>nul')
    lines.append(f'  ffmpeg -y -i "scenes\\scene5_scaled.mp4" '
                 f'-framerate {FPS} -i "scenes\\scene5_overlay\\frame_%%04d.png" '
                 f'-filter_complex "[1:v]format=rgba[ovr];'
                 f'[0:v][ovr]overlay=0:0:enable=\'gte(t,2.5)\'" '
                 f'-c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\\scene5.mp4" 2>nul')
    lines.append(')')
    lines.append('')

    lines.append('echo Building concat list...')
    lines.append('(')
    for name, _ in scenes_info[:4]:
        lines.append(f"  echo file '{name}.mp4'")
    lines.append(f"  if exist \"scenes\\scene5.mp4\" echo file 'scene5.mp4'")
    for name, _ in scenes_info[4:]:
        lines.append(f"  echo file '{name}.mp4'")
    lines.append(') > "scenes\\concat_list.txt"')
    lines.append('')

    lines.append('echo Concatenating...')
    lines.append(f'ffmpeg -y -f concat -safe 0 -i "scenes\\concat_list.txt" '
                 f'-c:v libx264 -pix_fmt yuv420p -crf 18 "scenes\\full_lowres.mp4" 2>nul')
    lines.append('')

    lines.append('echo Upscaling to 1920x1080...')
    lines.append(f'ffmpeg -y -i "scenes\\full_lowres.mp4" '
                 f'-vf "scale=1920:1080:flags=neighbor" '
                 f'-c:v libx264 -pix_fmt yuv420p -crf 15 '
                 f'"output\\scrapwright_intro_no_audio.mp4" 2>nul')
    lines.append('')
    lines.append('REM Add audio: ffmpeg -y -i "output\\scrapwright_intro_no_audio.mp4" -i "audio\\intro_music.mp3" -c:v copy -c:a aac -b:a 192k -shortest "output\\scrapwright_intro.mp4"')
    lines.append('echo.')
    lines.append('echo Done! Output: output\\scrapwright_intro_no_audio.mp4')
    lines.append('pause')

    with open(bat, 'w') as f:
        f.write('\r\n'.join(lines))
    print(f'  Assembly script: assemble.bat')


# ======================================================
# MAIN
# ======================================================

if __name__ == '__main__':
    ensure_dir(SCENES)
    ensure_dir(OUTPUT)

    if len(sys.argv) > 1 and sys.argv[1] == 'assemble':
        build_ffmpeg_script()
        sys.exit(0)

    print('=== Scrapwright Intro - Renderer v3 (Extended) ===')
    print(f'  Canvas: {W}x{H}  FPS: {FPS}  Duration: ~28s\n')

    render_scene1()
    render_scene2()
    render_scene3()
    render_scene4()
    render_scene5_bookends()
    render_scene6()
    render_scene7()
    render_scene8()
    render_scene9()
    print()
    build_ffmpeg_script()
    print()
    print('=== All scenes rendered! ===')
    print('  Run assemble.bat to build the final video')
