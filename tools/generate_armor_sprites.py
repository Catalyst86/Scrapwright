"""
Generate all 18 armor sprite sets for Scrapwright using PixelLab API v2.

Uses the Scrapwright Standard character as the base, then applies each armor
via transfer-outfit-v2 to create consistent variants.

Usage:
    python tools/generate_armor_sprites.py                  # Generate all missing armors
    python tools/generate_armor_sprites.py --armor leather_vest  # Generate one armor
    python tools/generate_armor_sprites.py --refs-only      # Only generate reference images
    python tools/generate_armor_sprites.py --list           # Show status of all armors
"""

import requests, base64, os, sys, time, json, argparse
from pathlib import Path
from PIL import Image
from concurrent.futures import ThreadPoolExecutor, as_completed

# ============================================================
# Configuration
# ============================================================

API_KEY = "033683bf-7368-465f-81a8-6e01192d8a1b"
HEADERS = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
BASE_URL = "https://api.pixellab.ai/v2"

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SPRITE_BASE = PROJECT_ROOT / "assets" / "sprites" / "player"
REFS_DIR = PROJECT_ROOT / "tools" / "armor_refs"
PROGRESS_FILE = PROJECT_ROOT / "tools" / "generation_progress.json"

IMG_SIZE = {"width": 64, "height": 64}

# Base armor folder (extracted from Scrapwright Standard)
BASE_TIER = "bandana_red"

# All 18 armors with outfit descriptions for transfer-outfit-v2
ARMORS = {
    "bandana_red": {
        "desc": None,  # Base — already extracted
        "prompt": None,
    },
    "bandana_blue": {
        "desc": "cute golden puppy with blue bandana around neck",
        "prompt": "change the red bandana to a blue bandana",
    },
    "leather_vest": {
        "desc": "cute golden puppy wearing brown leather vest",
        "prompt": "add a brown leather vest to the puppy",
    },
    "flower_crown": {
        "desc": "cute golden puppy wearing pink flower crown wreath on head",
        "prompt": "add a pink flower wreath crown on the puppy's head",
    },
    "pirate_patch": {
        "desc": "cute golden puppy with black eye patch and small pirate hat",
        "prompt": "add a black eye patch and small pirate hat to the puppy",
    },
    "golden_collar": {
        "desc": "cute golden puppy with ornate shiny gold collar necklace",
        "prompt": "add an ornate shiny golden collar around the puppy's neck",
    },
    "void_cloak": {
        "desc": "cute golden puppy wearing dark purple mystical glowing cloak",
        "prompt": "add a dark purple mystical glowing cloak to the puppy",
    },
    "phoenix_mantle": {
        "desc": "cute golden puppy wearing fiery orange-red feathered cape mantle",
        "prompt": "add a fiery orange-red feathered mantle cape to the puppy",
    },
    "party_hat": {
        "desc": "cute golden puppy wearing colorful striped cone party hat",
        "prompt": "add a colorful striped cone party hat on the puppy's head",
    },
    "goggles": {
        "desc": "cute golden puppy wearing blue aviator goggles on forehead",
        "prompt": "add blue aviator goggles on the puppy's forehead",
    },
    "rusty_plate": {
        "desc": "cute golden puppy in rusty brown worn plate armor",
        "prompt": "add rusty brown worn plate armor to the puppy",
    },
    "iron_mail": {
        "desc": "cute golden puppy in shiny grey iron chain mail armor",
        "prompt": "add grey iron chain mail armor to the puppy",
    },
    "crystal_vest": {
        "desc": "cute golden puppy in shimmering light-blue crystal armor vest",
        "prompt": "add shimmering light-blue crystal armor to the puppy",
    },
    "scrap_shield": {
        "desc": "cute golden puppy with cobbled grey scrap metal shield and armor plates",
        "prompt": "add cobbled together grey scrap metal armor and shield to the puppy",
    },
    "fungal_hide": {
        "desc": "cute golden puppy wearing green mossy fungal hide armor with mushrooms",
        "prompt": "add green mossy fungal hide armor with small mushrooms to the puppy",
    },
    "steam_harness": {
        "desc": "cute golden puppy with brass copper mechanical harness with small gears",
        "prompt": "add a brass and copper mechanical harness with gears to the puppy",
    },
    "junkyard_crown": {
        "desc": "cute golden puppy wearing makeshift golden crown made from junk parts",
        "prompt": "add a makeshift golden crown made from junk parts on the puppy's head",
    },
    "obsidian_shell": {
        "desc": "cute golden puppy in dark obsidian-black heavy shell armor",
        "prompt": "add dark obsidian-black heavy shell armor to the puppy",
    },
}

# Animations to process (all 8 game animations)
ANIMATIONS = ["idle", "run", "jump", "bark", "sneak", "death", "dig", "fall"]

# Directions per animation
FULL_DIRS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]

# Only generate these directions; mirror the rest to save API calls
GENERATE_DIRS = ["south", "south-east", "east", "north-east", "north"]
MIRROR_MAP = {
    "west": "east",            # flip east → west
    "north-west": "north-east",  # flip NE → NW
    "south-west": "south-east",  # flip SE → SW
}

ANIM_DIRS = {
    "idle": FULL_DIRS,
    "run": FULL_DIRS,
    "jump": FULL_DIRS,
    "bark": FULL_DIRS,
    "sneak": FULL_DIRS,
    "death": FULL_DIRS,
    "dig": ["south"],
    "fall": ["south"],
}


# ============================================================
# Helpers
# ============================================================

def load_progress() -> dict:
    if PROGRESS_FILE.exists():
        return json.loads(PROGRESS_FILE.read_text())
    return {"refs": {}, "transfers": {}}


def save_progress(progress: dict):
    PROGRESS_FILE.write_text(json.dumps(progress, indent=2))


def img_to_b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("utf-8")


def make_image_obj(path: Path) -> dict:
    """Create a PixelLab v2 image object: {type, base64, format}."""
    return {"type": "base64", "base64": img_to_b64(path), "format": "png"}


def make_image_obj_from_b64(b64_str: str) -> dict:
    """Create a PixelLab v2 image object from a base64 string."""
    return {"type": "base64", "base64": b64_str, "format": "png"}


def b64_to_img(b64_str: str, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(base64.b64decode(b64_str))


def poll_job(job_id: str, max_wait: int = 180) -> dict:
    """Poll an async background job until complete."""
    url = f"{BASE_URL}/background-jobs/{job_id}"
    start = time.time()
    while time.time() - start < max_wait:
        r = requests.get(url, headers=HEADERS, timeout=30)
        if r.status_code == 200:
            data = r.json()
            status = data.get("status", "")
            if status == "completed":
                return data
            if status == "failed":
                print(f"    Job {job_id[:8]} FAILED: {data.get('error', '?')}")
                return None
        elif r.status_code == 423:
            pass  # Still processing
        else:
            print(f"    Poll error: {r.status_code}")
        time.sleep(5)
    print(f"    Job {job_id[:8]} timed out after {max_wait}s")
    return None


def extract_images_from_job(data: dict) -> list:
    """Extract images from a completed background job response.
    Returns list of dicts with {base64, width, height, type} or raw b64 strings."""
    if not data:
        return []

    # transfer-outfit-v2 and edit-images-v2 put results in last_response
    lr = data.get("last_response", {})
    if isinstance(lr, dict):
        # Prefer quantized_images (pixel-art optimized, fewer colors)
        images = lr.get("quantized_images", lr.get("images", []))
        if images:
            return images

    # Fallback: check result, data, images at various levels
    for path_fn in [
        lambda d: d.get("images", []),
        lambda d: d.get("result", {}).get("images", []),
        lambda d: d.get("data", {}).get("images", []),
    ]:
        imgs = path_fn(data)
        if imgs:
            return imgs
    return []


def save_rgba_images(images: list, out_dir: Path) -> int:
    """Save rgba_bytes images as PNG files. Returns number saved."""
    out_dir.mkdir(parents=True, exist_ok=True)
    count = 0
    for i, img in enumerate(images):
        out_path = out_dir / f"frame_{i:03d}.png"
        if isinstance(img, dict) and img.get("type") == "rgba_bytes":
            w, h = img["width"], img["height"]
            raw = base64.b64decode(img["base64"])
            pil_img = Image.frombytes("RGBA", (w, h), raw)
            pil_img.save(out_path)
            count += 1
        elif isinstance(img, dict) and "base64" in img:
            out_path.write_bytes(base64.b64decode(img["base64"]))
            count += 1
        elif isinstance(img, str):
            out_path.write_bytes(base64.b64decode(img))
            count += 1
    return count


def mirror_direction(armor_id: str, anim: str, mirror_dir: str, source_dir: str):
    """Create mirrored frames by flipping source direction horizontally."""
    src_path = SPRITE_BASE / armor_id / anim / source_dir
    dst_path = SPRITE_BASE / armor_id / anim / mirror_dir

    if not src_path.exists():
        return 0

    if dst_path.exists() and list(dst_path.glob("frame_*.png")):
        return len(list(dst_path.glob("frame_*.png")))  # Already done

    dst_path.mkdir(parents=True, exist_ok=True)
    frames = sorted(src_path.glob("frame_*.png"))
    for frame_path in frames:
        img = Image.open(frame_path).convert("RGBA")
        flipped = img.transpose(Image.FLIP_LEFT_RIGHT)
        flipped.save(dst_path / frame_path.name)

    return len(frames)


def get_base_frames(anim: str, direction: str) -> list[Path]:
    """Get sorted list of base frame paths for an animation+direction."""
    dir_path = SPRITE_BASE / BASE_TIER / anim / direction
    if not dir_path.exists():
        return []
    frames = sorted(dir_path.glob("frame_*.png"))
    return frames


# ============================================================
# Step 1: Generate reference images for each armor
# ============================================================

def generate_reference(armor_id: str, progress: dict) -> Path:
    """Generate a reference image for an armor by editing the base south idle frame."""
    ref_path = REFS_DIR / f"{armor_id}_ref.png"

    if ref_path.exists():
        print(f"  Reference already exists: {armor_id}")
        return ref_path

    if armor_id in progress.get("refs", {}) and progress["refs"][armor_id] == "done":
        return ref_path

    armor = ARMORS[armor_id]
    prompt = armor["prompt"]
    if not prompt:
        return None  # Base armor, no reference needed

    # Load the base south idle frame as reference
    base_frame = SPRITE_BASE / BASE_TIER / "idle" / "south" / "frame_000.png"
    if not base_frame.exists():
        print(f"  ERROR: Base frame not found: {base_frame}")
        return None

    print(f"  Generating reference for {armor_id}...")

    # Use create-image-pixflux (synchronous, fast) for reference images
    payload = {
        "description": armor["desc"] + ", pixel art, top-down view, transparent background",
        "image_size": IMG_SIZE,
        "outline": "single color black outline",
        "shading": "medium shading",
        "detail": "medium detail",
        "no_background": True,
        "text_guidance_scale": 8,
        "seed": 42,
    }

    r = requests.post(f"{BASE_URL}/create-image-pixflux", headers=HEADERS, json=payload, timeout=60)

    if r.status_code == 200:
        data = r.json()
        # Extract image from response (may be in various locations)
        b64_data = None
        image = data.get("image") or data.get("data", {}).get("image")
        if isinstance(image, dict):
            b64_data = image.get("base64", "")
        elif isinstance(image, str):
            b64_data = image
        else:
            images = data.get("images", data.get("data", {}).get("images", []))
            if images:
                img = images[0]
                b64_data = img.get("base64", img) if isinstance(img, dict) else img

        if b64_data:
            REFS_DIR.mkdir(parents=True, exist_ok=True)
            b64_to_img(b64_data, ref_path)
            progress.setdefault("refs", {})[armor_id] = "done"
            save_progress(progress)
            print(f"    Saved reference: {ref_path.name}")
            return ref_path

    print(f"    Failed to generate reference for {armor_id}: {r.status_code} {r.text[:200]}")
    return None


# ============================================================
# Step 2: Transfer outfit to animation frames
# ============================================================

def transfer_outfit_batch(armor_id: str, ref_path: Path, anim: str, direction: str, progress: dict) -> bool:
    """Apply armor outfit to all frames of one animation+direction."""

    key = f"{armor_id}/{anim}/{direction}"
    if progress.get("transfers", {}).get(key) == "done":
        return True

    # Check if output already exists
    out_dir = SPRITE_BASE / armor_id / anim / direction
    if out_dir.exists() and list(out_dir.glob("frame_*.png")):
        progress.setdefault("transfers", {})[key] = "done"
        save_progress(progress)
        return True

    # Load base frames
    base_frames = get_base_frames(anim, direction)
    if not base_frames:
        print(f"    No base frames for {anim}/{direction}")
        return False

    # transfer-outfit-v2 accepts 2-16 frames
    # If more than 16, we need to batch
    all_output_frames = []
    batch_size = 8  # Keep batches small to avoid timeouts on 16-frame anims

    for batch_start in range(0, len(base_frames), batch_size):
        batch_frames = base_frames[batch_start:batch_start + batch_size]

        # Need at least 2 frames for transfer-outfit
        if len(batch_frames) < 2:
            # Duplicate the single frame to meet minimum
            batch_frames = batch_frames * 2

        # API format: reference_image = {image: {type, base64, format}, size: {width, height}}
        # frames[] = {image: {type, base64, format}, size: {width, height}}
        frames_payload = []
        for fp in batch_frames:
            frames_payload.append({"image": make_image_obj(fp), "size": IMG_SIZE})

        payload = {
            "reference_image": {"image": make_image_obj(ref_path), "size": IMG_SIZE},
            "frames": frames_payload,
            "image_size": IMG_SIZE,
            "no_background": True,
            "seed": 42,
        }

        r = requests.post(f"{BASE_URL}/transfer-outfit-v2", headers=HEADERS, json=payload, timeout=30)

        if r.status_code in (200, 202):
            resp = r.json()
            job_id = resp.get("background_job_id") or resp.get("data", {}).get("background_job_id")

            if job_id:
                result = poll_job(job_id, max_wait=300)
                images = extract_images_from_job(result)
            else:
                images = extract_images_from_job(resp)

            if images:
                all_output_frames.extend(images)
            else:
                print(f"    Transfer failed for {key}")
                return False
        else:
            print(f"    API error {r.status_code} for {key}: {r.text[:200]}")
            return False

    # Handle the duplicate frame case (we duplicated a single frame)
    if len(base_frames) == 1 and len(all_output_frames) >= 1:
        all_output_frames = all_output_frames[:1]

    # Save output frames as PNG
    saved = save_rgba_images(all_output_frames, out_dir)
    if saved == 0:
        print(f"    No images saved for {key}")
        return False

    progress.setdefault("transfers", {})[key] = "done"
    save_progress(progress)
    return True


# ============================================================
# Main pipeline
# ============================================================

MAX_CONCURRENT = 4  # Max parallel transfer-outfit jobs


MAX_FRAMES_PER_CALL = 8  # Cap to avoid timeouts on 16-frame animations


def submit_transfer_job(ref_path: Path, base_frames: list, armor_id: str, anim: str, direction: str) -> tuple:
    """Submit transfer-outfit-v2 job(s). Splits >8 frames into multiple jobs.
    Returns (key, job_ids_list, n_base_frames) where job_ids_list may have 1-2 entries."""
    key = f"{armor_id}/{anim}/{direction}"
    job_ids = []

    # Split into batches of MAX_FRAMES_PER_CALL
    for batch_start in range(0, len(base_frames), MAX_FRAMES_PER_CALL):
        batch_frames = base_frames[batch_start:batch_start + MAX_FRAMES_PER_CALL]
        if len(batch_frames) < 2:
            batch_frames = batch_frames * 2  # API requires min 2

        frames_payload = [{"image": make_image_obj(fp), "size": IMG_SIZE} for fp in batch_frames]
        payload = {
            "reference_image": {"image": make_image_obj(ref_path), "size": IMG_SIZE},
            "frames": frames_payload,
            "image_size": IMG_SIZE,
            "no_background": True,
            "seed": 42,
        }

        try:
            r = requests.post(f"{BASE_URL}/transfer-outfit-v2", headers=HEADERS, json=payload, timeout=30)
            if r.status_code in (200, 202):
                resp = r.json()
                job_id = resp.get("background_job_id") or resp.get("data", {}).get("background_job_id")
                job_ids.append((job_id, len(batch_frames), batch_start))
            elif r.status_code == 429:
                return (key, "RATE_LIMITED", len(base_frames))
            else:
                return (key, None, len(base_frames))
        except Exception as e:
            print(f"    Submit error for {key}: {e}")
            return (key, None, len(base_frames))

    if job_ids:
        return (key, job_ids, len(base_frames))
    return (key, None, len(base_frames))


def process_armor(armor_id: str, progress: dict):
    """Generate all animations for one armor variant using parallel API calls."""
    armor = ARMORS.get(armor_id)
    if not armor:
        print(f"Unknown armor: {armor_id}")
        return

    if armor_id == BASE_TIER:
        print(f"Skipping {armor_id} (base tier, already extracted)")
        return

    print(f"\n{'='*60}")
    print(f"Processing: {armor_id}")
    print(f"{'='*60}")

    ref_path = generate_reference(armor_id, progress)
    if not ref_path or not ref_path.exists():
        print(f"  FAILED to get reference for {armor_id}, skipping")
        return

    # Collect jobs — only generate unique directions, mirror the rest
    pending_jobs = []
    for anim in ANIMATIONS:
        dirs_needed = ANIM_DIRS[anim]
        # Only generate directions that can't be mirrored
        gen_dirs = [d for d in dirs_needed if d in GENERATE_DIRS or d not in MIRROR_MAP]
        for direction in gen_dirs:
            key = f"{armor_id}/{anim}/{direction}"
            if progress.get("transfers", {}).get(key) == "done":
                continue
            out_dir = SPRITE_BASE / armor_id / anim / direction
            if out_dir.exists() and list(out_dir.glob("frame_*.png")):
                progress.setdefault("transfers", {})[key] = "done"
                save_progress(progress)
                continue
            base_frames = get_base_frames(anim, direction)
            if base_frames:
                pending_jobs.append((anim, direction, base_frames))

    if not pending_jobs:
        print(f"  All animations already complete!")
        return

    total = len(pending_jobs)
    done = 0
    failed = 0

    # Process in batches of MAX_CONCURRENT
    i = 0
    while i < len(pending_jobs):
        batch = pending_jobs[i:i + MAX_CONCURRENT]
        # submitted[key] = (job_ids_list, n_base, anim, direction)
        # job_ids_list = [(job_id, batch_len, batch_start), ...]
        submitted = {}

        # Submit batch
        for anim, direction, base_frames in batch:
            key, job_info, n_base = submit_transfer_job(ref_path, base_frames, armor_id, anim, direction)
            if job_info and job_info != "RATE_LIMITED":
                submitted[key] = (job_info, n_base, anim, direction)
            elif job_info == "RATE_LIMITED":
                print(f"  Rate limited, waiting 30s...")
                time.sleep(30)
                key, job_info, n_base = submit_transfer_job(ref_path, base_frames, armor_id, anim, direction)
                if job_info and job_info != "RATE_LIMITED":
                    submitted[key] = (job_info, n_base, anim, direction)
                else:
                    failed += 1
                    done += 1
            else:
                failed += 1
                done += 1

        # Poll all submitted jobs — each key may have multiple sub-jobs
        remaining = dict(submitted)
        # Track completed images per key: {key: {batch_start: [images]}}
        collected = {key: {} for key in remaining}
        poll_start = time.time()

        while remaining and (time.time() - poll_start) < 300:
            time.sleep(5)
            for key, (job_ids_list, n_base, anim, direction) in list(remaining.items()):
                all_done = True
                for job_id, batch_len, batch_start in job_ids_list:
                    if batch_start in collected[key]:
                        continue  # Already collected this sub-job
                    try:
                        r = requests.get(f"{BASE_URL}/background-jobs/{job_id}", headers=HEADERS, timeout=30)
                        data = r.json()
                        status = data.get("status", "")

                        if status == "completed":
                            images = extract_images_from_job(data)
                            collected[key][batch_start] = images
                        elif status == "failed":
                            collected[key][batch_start] = None  # Mark as failed
                        else:
                            all_done = False
                    except Exception:
                        all_done = False

                if all_done:
                    # Assemble all sub-batches in order
                    all_images = []
                    any_failed = False
                    for _, _, bs in sorted(job_ids_list, key=lambda x: x[2]):
                        sub_imgs = collected[key].get(bs)
                        if sub_imgs is None:
                            any_failed = True
                            break
                        all_images.extend(sub_imgs)

                    if not any_failed and all_images:
                        if n_base == 1:
                            all_images = all_images[:1]
                        out_dir = SPRITE_BASE / armor_id / anim / direction
                        saved = save_rgba_images(all_images, out_dir)
                        progress.setdefault("transfers", {})[key] = "done"
                        save_progress(progress)
                        done += 1
                        print(f"  [{done}/{total}] {anim}/{direction} OK ({saved} frames)")
                    else:
                        done += 1
                        failed += 1
                        print(f"  [{done}/{total}] {anim}/{direction} FAILED")
                    del remaining[key]

        # Mark remaining as timed out
        for key in remaining:
            done += 1
            failed += 1
            _, _, anim, direction = submitted[key]
            print(f"  [{done}/{total}] {anim}/{direction} TIMEOUT")

        i += len(batch)
        time.sleep(1)

    print(f"\n  {armor_id}: {done - failed}/{total} generated, {failed} failed")

    # Mirror east→west, NE→NW, SE→SW for all animations
    mirrored = 0
    for anim in ANIMATIONS:
        dirs_needed = ANIM_DIRS[anim]
        for mirror_dir, source_dir in MIRROR_MAP.items():
            if mirror_dir in dirs_needed:
                count = mirror_direction(armor_id, anim, mirror_dir, source_dir)
                if count > 0:
                    mirrored += 1
                    key = f"{armor_id}/{anim}/{mirror_dir}"
                    progress.setdefault("transfers", {})[key] = "done"
    if mirrored:
        save_progress(progress)
        print(f"  Mirrored {mirrored} direction sets (E>W, NE>NW, SE>SW)")


def show_status():
    """Show which armors have complete sprite sets."""
    print(f"\n{'Armor ID':20s} | {'Anims':6s} | {'Status':10s}")
    print("-" * 45)

    for armor_id in ARMORS:
        armor_dir = SPRITE_BASE / armor_id
        if not armor_dir.exists():
            print(f"{armor_id:20s} | {'0/8':6s} | MISSING")
            continue

        complete = 0
        for anim in ANIMATIONS:
            anim_dir = armor_dir / anim
            if not anim_dir.exists():
                continue
            dirs_needed = ANIM_DIRS[anim]
            all_dirs_ok = True
            for d in dirs_needed:
                d_path = anim_dir / d
                if not d_path.exists() or not list(d_path.glob("frame_*.png")):
                    all_dirs_ok = False
                    break
            if all_dirs_ok:
                complete += 1

        status = "COMPLETE" if complete == 8 else "PARTIAL"
        print(f"{armor_id:20s} | {complete}/8   | {status}")


def main():
    parser = argparse.ArgumentParser(description="Generate armor sprites via PixelLab API")
    parser.add_argument("--armor", type=str, help="Generate only this armor ID")
    parser.add_argument("--refs-only", action="store_true", help="Only generate reference images")
    parser.add_argument("--list", action="store_true", help="Show status of all armors")
    args = parser.parse_args()

    if args.list:
        show_status()
        return

    progress = load_progress()

    if args.armor:
        if args.refs_only:
            generate_reference(args.armor, progress)
        else:
            process_armor(args.armor, progress)
    else:
        # Process all armors
        if args.refs_only:
            print("Generating reference images for all armors...")
            for armor_id in ARMORS:
                if armor_id == BASE_TIER:
                    continue
                generate_reference(armor_id, progress)
        else:
            for armor_id in ARMORS:
                process_armor(armor_id, progress)

    print("\n" + "=" * 60)
    print("Generation complete!")
    show_status()


if __name__ == "__main__":
    main()
