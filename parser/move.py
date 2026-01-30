import os
import json
import shutil

species_json_path = "assets/data/species.json"
species_images_dir = "assets/species-images"
range_images_dir = "assets/range-images"

# Load all valid ids from species.json
with open(species_json_path, "r") as f:
    species_data = json.load(f)

valid_ids = set()
for entry in species_data:
    id_val = entry.get("id")
    if id_val:
        valid_ids.add(id_val)

def move_unmatched_images(images_dir, valid_ids):
    other_dir = os.path.join(images_dir, "other")
    os.makedirs(other_dir, exist_ok=True)
    for fname in os.listdir(images_dir):
        fpath = os.path.join(images_dir, fname)
        if os.path.isdir(fpath):
            continue
        # Check if file matches any id (prefix match, ignoring extension)
        base = os.path.splitext(fname)[0]
        if base not in valid_ids:
            print(f"Moving {fname} to {other_dir}")
            shutil.move(fpath, os.path.join(other_dir, fname))

move_unmatched_images(species_images_dir, valid_ids)
move_unmatched_images(range_images_dir, valid_ids)
print("Done.")