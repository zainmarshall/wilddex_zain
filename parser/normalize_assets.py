#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path


RANKS = ["kingdom", "phylum", "class", "order", "family", "genus", "species"]


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "_", value)
    return value.strip("_")


def taxon_id(rank: str, name: str) -> str:
    return f"taxon:{rank}:{slugify(name)}"


def load_json(path: Path):
    return json.loads(path.read_text())


def main():
    parser = argparse.ArgumentParser(description="Normalize WildDex JSON assets.")
    parser.add_argument("--species", required=True, help="Path to species.json")
    parser.add_argument("--taxa", required=True, help="Path to taxa.json")
    parser.add_argument(
        "--out-species",
        required=True,
        help="Path to write species_normalized.json",
    )
    parser.add_argument(
        "--out-taxa",
        required=True,
        help="Path to write taxa_normalized.json",
    )
    args = parser.parse_args()

    species_list = load_json(Path(args.species))
    taxa_list = load_json(Path(args.taxa))

    taxa_by_key = {}
    conflicts = 0

    def ensure_taxon(rank: str, name: str):
        if not name:
            return None
        key = f"{rank}|{name.lower()}"
        if key in taxa_by_key:
            return taxa_by_key[key]
        entry = {
            "id": taxon_id(rank, name),
            "rank": rank,
            "name": name,
            "common_name": "",
            "scientific_name": "",
            "description": "",
            "parent_id": None,
        }
        taxa_by_key[key] = entry
        return entry

    # Seed from species classification
    normalized_species = []
    for sp in species_list:
        classification = sp.get("classification") or {}
        rank_ids = {}
        prev_entry = None
        for rank in RANKS:
            name = classification.get(rank)
            entry = ensure_taxon(rank, name)
            if entry:
                rank_ids[rank] = entry["id"]
                if prev_entry and entry.get("parent_id") in (None, "", prev_entry["id"]):
                    if entry.get("parent_id") is None:
                        entry["parent_id"] = prev_entry["id"]
                elif prev_entry and entry.get("parent_id") != prev_entry["id"]:
                    conflicts += 1
                prev_entry = entry
            else:
                prev_entry = None

        normalized_species.append(
            {
                "id": sp.get("id", ""),
                "common_name": sp.get("common_name", ""),
                "scientific_name": sp.get("scientific_name", ""),
                "iucn_status": sp.get("iucn_status"),
                "summary": sp.get("summary", ""),
                "kingdom_id": rank_ids.get("kingdom"),
                "phylum_id": rank_ids.get("phylum"),
                "class_id": rank_ids.get("class"),
                "order_id": rank_ids.get("order"),
                "family_id": rank_ids.get("family"),
                "genus_id": rank_ids.get("genus"),
                "species_id": rank_ids.get("species"),
            }
        )

    # Enrich from taxa.json
    for t in taxa_list:
        rank = (t.get("rank") or "").lower()
        if not rank:
            continue
        candidates = [
            t.get("name"),
            t.get("scientific_name"),
            t.get("common_name"),
        ]
        entry = None
        for name in candidates:
            if not name:
                continue
            entry = ensure_taxon(rank, name)
            if entry:
                break
        if not entry:
            continue
        if not entry.get("common_name") and t.get("common_name"):
            entry["common_name"] = t.get("common_name") or ""
        if not entry.get("scientific_name") and t.get("scientific_name"):
            entry["scientific_name"] = t.get("scientific_name") or ""
        if not entry.get("description") and t.get("description"):
            entry["description"] = t.get("description") or ""

    taxa_output = sorted(
        taxa_by_key.values(),
        key=lambda x: (RANKS.index(x["rank"]) if x["rank"] in RANKS else 99, x["name"]),
    )

    Path(args.out_species).write_text(json.dumps(normalized_species, indent=2))
    Path(args.out_taxa).write_text(json.dumps(taxa_output, indent=2))

    if conflicts:
        print(f"Parent conflicts detected: {conflicts}", file=sys.stderr)


if __name__ == "__main__":
    main()
