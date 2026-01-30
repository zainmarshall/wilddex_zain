# extract.py


import json
import os

def extract_species(file):
    species = []
    with open(file, 'r') as f:
        data = json.load(f)
        for key in data.keys():
            if isinstance(key, str) and ';' in key and not key.startswith("aves;"):
                species.append(key)

    species = [header for header in species if not header.startswith("allow")]
    return species

def save_species_to_json(species, output_file):
    with open(output_file, 'w') as f:
        json.dump(species, f, indent=4)

def extract_genus_and_species(species):
    genus_species = []    
    for item in species:
        if item.startswith("aves;"):
            continue
        parts = item.split(';')
        if len(parts) >= 3:
            genus_species.append({
                'genus': parts[-2],
                'species': parts[-1]
            })
    return genus_species

if __name__ == "__main__":
    input_file = 'geofence_base.json'
    output_file = 'specieslist.json'
    genus_species_file = 'genus_species.json'
    
    if os.path.exists(input_file):
        species = extract_species(input_file)
        save_species_to_json(species, output_file)
        print(f"Extracted {len(species)} species and saved to {output_file}")
        genus_species = extract_genus_and_species(species)
        print(f"Extracted genus and species pairs: {genus_species}")
        save_species_to_json(genus_species, genus_species_file)
        print(f"Genus and species pairs saved to {genus_species_file}")
    else:
        print(f"Input file {input_file} does not exist.")



