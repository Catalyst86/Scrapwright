"""
Stitch Kling videos + title card into final Scrapwright intro.

Instructions:
1. Download all Kling videos to: scrapwright_intro/kling_videos/
2. Rename them in order:
   - clip1_sad.mp4       (puppy alone in junkyard, rain)
   - clip2_timelapse.mp4  (days passing, lonely)
   - clip3_fall.mp4       (ground cracks, falls into dungeon)
   - clip4_hero.mp4       (zoom in, devilish grin)
3. Run this script: python stitch_intro.py
"""

import subprocess
import os
import sys
from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
VIDEO_DIR = os.path.join(SCRIPT_DIR, "kling_videos")
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "output")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Expected clips in order
CLIPS = [
    "clip1_sad.mp4.mp4",
    "clip2_timelapse.mp4.mp4",
    "clip3_fall.mp4.mp4",
    "clip4_hero.mp4.mp4",
]

def check_clips():
    """Verify all clips exist."""
    missing = []
    found = []
    for clip in CLIPS:
        path = os.path.join(VIDEO_DIR, clip)
        if os.path.exists(path):
            found.append(clip)
        else:
            missing.append(clip)

    if missing:
        print("WARNING: Missing clips:")
        for m in missing:
            print(f"  - {m}")
        print(f"\nPlace them in: {VIDEO_DIR}")
        print("\nAvailable files in that folder:")
        if os.path.exists(VIDEO_DIR):
            for f in os.listdir(VIDEO_DIR):
                print(f"  - {f}")
        else:
            print("  (folder doesn't exist yet)")

    return found, missing


def render_title_card(width=1920, height=1080, fps=30, duration=4):
    """Render the SCRAPWRIGHT title card as a video clip."""
    print("Rendering title card...")

    frames_dir = os.path.join(OUTPUT_DIR, "title_frames")
    os.makedirs(frames_dir, exist_ok=True)

    total_frames = fps * duration

    for frame_num in range(total_frames):
        t = frame_num / total_frames  # 0.0 to 1.0

        img = Image.new('RGBA', (width, height), (0, 0, 0, 255))
        draw = ImageDraw.Draw(img)

        # Fade in the title text
        if t < 0.3:
            alpha = int(255 * (t / 0.3))
        elif t > 0.85:
            alpha = int(255 * ((1.0 - t) / 0.15))
        else:
            alpha = 255

        # Title: SCRAPWRIGHT
        title = "SCRAPWRIGHT"
        try:
            title_font = ImageFont.truetype("arial.ttf", 72)
            sub_font = ImageFont.truetype("arial.ttf", 24)
        except:
            title_font = ImageFont.load_default()
            sub_font = ImageFont.load_default()

        # Gold color with fade
        gold = (218, 165, 32, alpha)
        white = (200, 200, 200, alpha)

        # Center title
        bbox = draw.textbbox((0, 0), title, font=title_font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        tx = (width - tw) // 2
        ty = (height // 2) - th - 20

        draw.text((tx, ty), title, fill=gold, font=title_font)

        # Subtitle
        subtitle = "Every scrap has a story"
        bbox2 = draw.textbbox((0, 0), subtitle, font=sub_font)
        sw = bbox2[2] - bbox2[0]
        sx = (width - sw) // 2
        sy = ty + th + 30

        # Subtitle fades in slightly later
        if t > 0.3:
            sub_t = (t - 0.3) / 0.3
            sub_alpha = min(int(255 * sub_t), alpha)
            sub_color = (200, 200, 200, sub_alpha)
            draw.text((sx, sy), subtitle, fill=sub_color, font=sub_font)

        # Save frame
        frame_path = os.path.join(frames_dir, f"frame_{frame_num:04d}.png")
        img.save(frame_path)

    # Encode title card to video
    title_video = os.path.join(OUTPUT_DIR, "title_card.mp4")
    subprocess.run([
        "ffmpeg", "-y",
        "-framerate", str(fps),
        "-i", os.path.join(frames_dir, "frame_%04d.png"),
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-preset", "slow",
        "-crf", "18",
        title_video
    ], check=True, capture_output=True)

    # Cleanup frames
    for f in os.listdir(frames_dir):
        os.remove(os.path.join(frames_dir, f))
    os.rmdir(frames_dir)

    print(f"Title card: {title_video}")
    return title_video


def normalize_clip(input_path, output_path, target_w=1920, target_h=1080, target_fps=30):
    """Normalize a clip to consistent resolution, fps, and codec."""
    subprocess.run([
        "ffmpeg", "-y",
        "-i", input_path,
        "-vf", f"scale={target_w}:{target_h}:force_original_aspect_ratio=decrease,"
               f"pad={target_w}:{target_h}:(ow-iw)/2:(oh-ih)/2:black,"
               f"fps={target_fps}",
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-preset", "slow",
        "-crf", "18",
        "-c:a", "aac",
        "-ar", "44100",
        "-ac", "2",
        "-shortest",
        output_path
    ], check=True, capture_output=True)


def get_duration(clip_path):
    """Get duration of a video clip in seconds."""
    result = subprocess.run([
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        clip_path
    ], capture_output=True, text=True)
    return float(result.stdout.strip())


def add_crossfade(clip_a, clip_b, output_path, fade_duration=0.5):
    """Add crossfade transition between two clips."""
    dur_a = get_duration(clip_a)
    offset = dur_a - fade_duration

    subprocess.run([
        "ffmpeg", "-y",
        "-i", clip_a,
        "-i", clip_b,
        "-filter_complex",
        f"[0:v]setpts=PTS-STARTPTS[v0];"
        f"[1:v]setpts=PTS-STARTPTS[v1];"
        f"[v0][v1]xfade=transition=fade:duration={fade_duration}:offset={offset}[outv];"
        f"[0:a][1:a]acrossfade=d={fade_duration}[outa]",
        "-map", "[outv]",
        "-map", "[outa]",
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-preset", "slow",
        "-crf", "18",
        output_path
    ], check=True, capture_output=True)


def add_fade_to_black(clip_a, clip_b, output_path, fade_duration=0.8, black_hold=0.5):
    """Fade clip_a to black, hold black, then fade in clip_b."""
    dur_a = get_duration(clip_a)

    # Fade out end of clip_a, fade in start of clip_b, with black gap
    subprocess.run([
        "ffmpeg", "-y",
        "-i", clip_a,
        "-i", clip_b,
        "-filter_complex",
        f"[0:v]fade=t=out:st={dur_a - fade_duration}:d={fade_duration}[v0];"
        f"[1:v]fade=t=in:st=0:d={fade_duration}[v1];"
        f"color=black:s=1920x1080:d={black_hold}[black];"
        f"[v0][black][v1]concat=n=3:v=1:a=0[outv];"
        f"[0:a]afade=t=out:st={dur_a - fade_duration}:d={fade_duration}[a0];"
        f"[1:a]afade=t=in:st=0:d={fade_duration}[a1];"
        f"anullsrc=r=44100:cl=stereo[ablack];"
        f"[ablack]atrim=0:{black_hold}[ablackt];"
        f"[a0][ablackt][a1]concat=n=3:v=0:a=1[outa]",
        "-map", "[outv]",
        "-map", "[outa]",
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-preset", "slow",
        "-crf", "18",
        output_path
    ], check=True, capture_output=True)


def stitch_simple(clip_paths, output_path):
    """Simple concatenation with crossfade transitions."""
    if len(clip_paths) == 0:
        print("No clips to stitch!")
        return

    if len(clip_paths) == 1:
        import shutil
        shutil.copy2(clip_paths[0], output_path)
        return

    # Normalize all clips first
    normalized = []
    for i, clip in enumerate(clip_paths):
        norm_path = os.path.join(OUTPUT_DIR, f"norm_{i}.mp4")
        print(f"Normalizing: {os.path.basename(clip)}...")
        normalize_clip(clip, norm_path)
        normalized.append(norm_path)

    # Concatenate with crossfades
    print("Stitching with crossfade transitions...")

    # Build concat file for simple concat (fallback)
    concat_file = os.path.join(OUTPUT_DIR, "concat.txt")
    with open(concat_file, 'w') as f:
        for norm in normalized:
            f.write(f"file '{norm}'\n")

    # Clip indices where we want fade-to-black instead of crossfade
    # Between clip3_fall (index 2) and clip4_hero (index 3)
    fade_to_black_after = {2}

    # Try crossfade approach first
    try:
        current = normalized[0]
        for i in range(1, len(normalized)):
            next_output = os.path.join(OUTPUT_DIR, f"merged_{i}.mp4")
            # Check if previous clip index needs fade-to-black
            prev_clip_idx = i - 1
            if prev_clip_idx in fade_to_black_after:
                print(f"  Fade to black between clips {prev_clip_idx+1} and {i+1}...")
                add_fade_to_black(current, normalized[i], next_output,
                                  fade_duration=0.8, black_hold=0.5)
            else:
                add_crossfade(current, normalized[i], next_output, fade_duration=0.5)
            current = next_output

        import shutil
        shutil.copy2(current, output_path)
        print("Stitching complete!")

    except Exception as e:
        print(f"Crossfade failed ({e}), falling back to simple concat...")
        subprocess.run([
            "ffmpeg", "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", concat_file,
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-preset", "slow",
            "-crf", "18",
            "-c:a", "aac",
            output_path
        ], check=True, capture_output=True)

    # Cleanup temp files
    for f in normalized:
        if os.path.exists(f):
            os.remove(f)
    for f in os.listdir(OUTPUT_DIR):
        if f.startswith("merged_"):
            os.remove(os.path.join(OUTPUT_DIR, f))
    if os.path.exists(concat_file):
        os.remove(concat_file)


def main():
    print("=== Scrapwright Intro Stitcher ===\n")

    found, missing = check_clips()

    if missing:
        print(f"\n{len(missing)} clips missing. Download them from Kling first.")
        resp = input("Continue with available clips? (y/n): ").strip().lower()
        if resp != 'y':
            sys.exit(1)

    if not found:
        print("No clips found. Exiting.")
        sys.exit(1)

    clip_paths = [os.path.join(VIDEO_DIR, c) for c in CLIPS if c in found]

    # Add title card if it exists
    title_card = os.path.join(OUTPUT_DIR, "title_card.mp4")
    if os.path.exists(title_card):
        clip_paths.append(title_card)
        print(f"Including title card: {title_card}")

    # Stitch everything
    final_output = os.path.join(OUTPUT_DIR, "scrapwright_intro_final.mp4")
    stitch_simple(clip_paths, final_output)

    size_mb = os.path.getsize(final_output) / (1024 * 1024)
    print(f"\nDone! Final video: {final_output}")
    print(f"Size: {size_mb:.1f} MB")


if __name__ == "__main__":
    main()
