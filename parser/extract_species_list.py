#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Extract species list from species.json")
    parser.add_argument(
        "--input",
        required=True,
        help="Path to species.json (list of species objects)",
    )
    parser.add_argument(
        "--out_dir",
        default="SpeciesList",
        help="Output directory for specieslist.json and genus_species.json",
    )
    args = parser.parse_args()

    data = json.loads(Path(args.input).read_text())
    if not isinstance(data, list):
        raise ValueError("Input species.json must be a list.")

    specieslist = []
    genus_species = []
    for item in data:
        sci = (item.get("scientific_name") or "").strip()
        if not sci:
            continue
        specieslist.append(sci.lower())
        parts = sci.split()
        if len(parts) >= 2:
            genus_species.append({"genus": parts[0], "species": parts[1]})

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "specieslist.json").write_text(json.dumps(specieslist, indent=2))
    (out_dir / "genus_species.json").write_text(json.dumps(genus_species, indent=2))


if __name__ == "__main__":
    main()
