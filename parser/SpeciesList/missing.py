# Calculates missing.json: genus/species in genus_species.json that are not in species.json
import json
import os

def main():
    # Paths
    genus_species_path = "SpeciesList/genus_species.json"
    species_path = "assets/data/species.json"
    missing_path = "SpeciesList/missing.json"

    # Load genus_species.json (list of {genus, species})
    with open(genus_species_path, "r") as f:
        genus_species_list = json.load(f)

    # Load species.json (dict with 'species' and 'higher_taxa')
    with open(species_path, "r") as f:
        species_json = json.load(f)
    if isinstance(species_json, dict):
        species_data = species_json.get("species", [])
    else:
        species_data = species_json

    # Build set of (genus, species) in species.json
    present = set()
    for s in species_data:
        c = s.get("classification", {})
        genus = c.get("genus", "").strip().lower()
        species = c.get("species", "").strip().lower()
        if genus and species:
            present.add((genus, species))

    # Find missing
    missing = []
    for entry in genus_species_list:
        genus = entry.get("genus", "").strip().lower()
        species = entry.get("species", "").strip().lower()
        if genus and species and (genus, species) not in present:
            missing.append({"genus": entry.get("genus", "").strip(), "species": entry.get("species", "").strip()})

    # Write missing.json
    with open(missing_path, "w") as f:
        json.dump(missing, f, indent=2)
    print(f"Wrote {len(missing)} missing species to {missing_path}")

if __name__ == "__main__":
    main()
