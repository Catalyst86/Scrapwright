"""Fix all player sprite .import files: set fix_alpha_border=false and clear cached .ctex files."""
import os, glob

PLAYER_DIR = r'C:\Users\danie\Desktop\roguelite\assets\sprites\player'
IMPORTED_DIR = r'C:\Users\danie\Desktop\roguelite\.godot\imported'

count_imports = 0
count_cache = 0

# Fix all .import files
for import_path in glob.glob(os.path.join(PLAYER_DIR, '**', '*.import'), recursive=True):
    with open(import_path, 'r') as f:
        content = f.read()

    if 'fix_alpha_border=true' in content:
        content = content.replace('fix_alpha_border=true', 'fix_alpha_border=false')
        with open(import_path, 'w') as f:
            f.write(content)
        count_imports += 1

# Clear cached .ctex files for player sprites (frame_*.ctex)
if os.path.isdir(IMPORTED_DIR):
    for ctex_path in glob.glob(os.path.join(IMPORTED_DIR, 'frame_*')):
        os.remove(ctex_path)
        count_cache += 1

print(f'Fixed {count_imports} .import files')
print(f'Cleared {count_cache} cached .ctex files')
