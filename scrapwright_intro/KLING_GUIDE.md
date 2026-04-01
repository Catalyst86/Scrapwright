# Scrapwright Intro — Kling 3.0 Production Guide

## Reference Images
All in `kling_refs/` folder. Upload these as start/end frames in Kling.

## Settings
- **Model:** VIDEO 3.0
- **Resolution:** 1080p
- **Aspect:** 16:9
- **Duration:** 10s (or max available)
- **Multi-Shot:** ON
- **Native Audio:** ON

---

## GENERATION 1 — Scenes 1-3 (Sad Arc)

Upload `scene1_start.png` as start frame.
Upload `scene3_start.png` as end frame.

### Prompt:
```
Pixel art animation style, 16-bit retro game aesthetic throughout.

Shot 1: A small golden puppy dog trots alone through a dark steampunk junkyard wasteland. Rusty scrap metal piles, broken gears, dark purple moody sky. Camera slowly pans right following the dog. Dust particles float. Lonely, melancholy atmosphere.

Shot 2: A large dark boot swings into frame and kicks a tin can toward the small golden dog. The dog flinches and cowers away in fear. Dust kicks up. The dog looks small and vulnerable.

Shot 3: The small golden dog sits alone in the center of a very dark junkyard at night, head down, looking sad and defeated. Dim moonlight. Camera slowly zooms in. Extremely melancholy and desolate.
```

---

## GENERATION 2 — Scenes 4-5 (Cataclysm Arc)

Upload `scene4_start.png` as start frame.
Upload `scene5_start.png` as end frame.

### Prompt:
```
Pixel art animation style, 16-bit retro game aesthetic throughout.

Shot 1: The ground of a dark junkyard begins shaking violently. Cracks spread across the earth. Red-orange glow erupts from below. The small golden dog barks in fear and looks around frantically. Debris falls from the sky. Screen shakes with increasing intensity. Apocalyptic earthquake.

Shot 2: Massive explosion erupts from the ground. Molten lava and debris fly upward. Huge shockwave destroys piles of scrap metal. Fire, chaos, destruction. Amidst the destruction, a small glowing cyan-gold metal shard tumbles through the air and falls to the ground.
```

---

## GENERATION 3 — Scenes 6-7 (Hero Arc)

Upload `scene6_start.png` as start frame.
Upload `scene7_end.png` as end frame.

### Prompt:
```
Pixel art animation style, 16-bit retro game aesthetic throughout.

Shot 1: In a dark junkyard at night, the small golden puppy dog cautiously approaches a glowing cyan-gold magical metal shard on the ground. The dog sniffs it and touches it with a paw. A massive flash of white and cyan magic energy explodes outward. The dog recoils with wide eyes. Magical sparkles fill the air.

Shot 2: Dark red apocalyptic sky with fires burning. Black silhouettes of people run in panic across the scene. The small golden dog stands firm in the center foreground, a glowing cyan-gold artifact at its feet. Camera slowly zooms in on the dog's face. Expression shifts from scared to determined and brave. Golden and cyan light glows around it. Heroic moment.
```

---

## POST-PRODUCTION (text cards + assembly)

### Scenes 8-9 (keep from PIL renderer)
The tagline and title cards from `render_intro.py` scenes 8-9 look fine.
Re-render just those if needed:
```bash
cd scrapwright_intro
python -c "
from render_intro import render_scene8, render_scene9, build_ffmpeg_script, ensure_dir, SCENES, OUTPUT
ensure_dir(SCENES); ensure_dir(OUTPUT)
render_scene8(); render_scene9()
"
```

Then encode them:
```bash
ffmpeg -y -framerate 24 -i scenes/scene8/frame_%04d.png -c:v libx264 -pix_fmt yuv420p -crf 18 scenes/scene8.mp4
ffmpeg -y -framerate 24 -i scenes/scene9/frame_%04d.png -c:v libx264 -pix_fmt yuv420p -crf 18 scenes/scene9.mp4
```

### Final assembly
Save your 3 Kling clips as:
- `kling_refs/gen1_sad.mp4`
- `kling_refs/gen2_cataclysm.mp4`
- `kling_refs/gen3_hero.mp4`

Then stitch:
```bash
cd scrapwright_intro

# Normalize all to 1080p 24fps
ffmpeg -y -i kling_refs/gen1_sad.mp4 -vf "scale=1920:1080,fps=24" -c:v libx264 -crf 18 scenes/kling1.mp4
ffmpeg -y -i kling_refs/gen2_cataclysm.mp4 -vf "scale=1920:1080,fps=24" -c:v libx264 -crf 18 scenes/kling2.mp4
ffmpeg -y -i kling_refs/gen3_hero.mp4 -vf "scale=1920:1080,fps=24" -c:v libx264 -crf 18 scenes/kling3.mp4

# Upscale text cards to match
ffmpeg -y -i scenes/scene8.mp4 -vf "scale=1920:1080:flags=neighbor,fps=24" -c:v libx264 -crf 18 scenes/kling_s8.mp4
ffmpeg -y -i scenes/scene9.mp4 -vf "scale=1920:1080:flags=neighbor,fps=24" -c:v libx264 -crf 18 scenes/kling_s9.mp4

# Concat
cat > scenes/final_concat.txt << EOF
file 'kling1.mp4'
file 'kling2.mp4'
file 'kling3.mp4'
file 'kling_s8.mp4'
file 'kling_s9.mp4'
EOF

ffmpeg -y -f concat -safe 0 -i scenes/final_concat.txt -c:v libx264 -crf 15 output/scrapwright_intro_final.mp4

echo "Done! -> output/scrapwright_intro_final.mp4"
```

### Add music later
```bash
ffmpeg -y -i output/scrapwright_intro_final.mp4 -i audio/intro_music.mp3 -c:v copy -c:a aac -b:a 192k -shortest output/scrapwright_intro_with_music.mp4
```

---

## Tips for Best Results in Kling 3.0

1. **Character consistency:** Upload `dog_reference.png` in the Assets panel and reference it
2. **If the dog looks different between generations:** Use the same start frame image and describe the dog identically each time: "small golden puppy dog with big dark eyes"
3. **If pixel art style breaks:** Add "chunky pixels, no anti-aliasing, limited color palette" to the prompt
4. **Native Audio:** Leave it ON — it'll generate junkyard ambience, rumbling, explosion sounds, magic sparkles automatically
5. **Iterate:** Generate each clip 2-3 times and pick the best one
6. **Multi-Shot timing:** Kling handles transitions between shots automatically — you don't need crossfades
