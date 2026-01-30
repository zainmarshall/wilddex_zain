import json
import os
import requests
from requests.adapters import HTTPAdapter, Retry
import time
from tqdm import tqdm
from pathlib import Path
import argparse

# Constants
GENUS_SPECIES_PATH = "SpeciesList/genus_species.json"
OUTPUT_JSON_PATH = "assets/data/species.json"
IMAGES_DIR = "assets/images"
DATA_DIR = "assets/data"
USER_AGENT = "WildDexParser"
SPARQL_ENDPOINT = "https://query.wikidata.org/sparql"
WIKI_SUMMARY_ENDPOINT = "https://en.wikipedia.org/api/rest_v1/page/summary/"
COMMONS_FILEPATH = "https://commons.wikimedia.org/wiki/Special:FilePath/"
RATE_LIMIT = 0.01
REQUEST_TIMEOUT = 20

def ensure_dirs():
    Path(IMAGES_DIR).mkdir(parents=True, exist_ok=True)
    Path(DATA_DIR).mkdir(parents=True, exist_ok=True)

def _normalize_species_list(raw_list):
    if not raw_list:
        return []
    first = raw_list[0]
    if isinstance(first, dict) and "genus" in first and "species" in first:
        return raw_list
    if isinstance(first, dict) and "scientific_name" in first:
        normalized = []
        for item in raw_list:
            sci = item.get("scientific_name") or ""
            parts = sci.split(" ")
            genus = parts[0] if parts else ""
            species = parts[1] if len(parts) > 1 else ""
            normalized.append({"genus": genus, "species": species, "_existing": item})
        return normalized
    raise ValueError("Unsupported species list format.")


def load_species_list(path=GENUS_SPECIES_PATH):
    with open(path) as f:
        raw_list = json.load(f)
    return _normalize_species_list(raw_list)

session = requests.Session()
retries = Retry(
    total=5,
    backoff_factor=1.5,
    status_forcelist=[429, 500, 502, 503, 504],
)
session.mount("https://", HTTPAdapter(max_retries=retries))


def sparql_query(scientific_name):
    # Step 1: Get Q-ID for scientific name
    # Try with double quotes and both original/capitalized forms
    def get_qid(name):
        qid_query = f"""
        SELECT ?item WHERE {{
          ?item wdt:P225 \"{name}\".
        }}
        """
        qid_resp = session.get(
            SPARQL_ENDPOINT,
            params={"query": qid_query, "format": "json"},
            headers={"User-Agent": USER_AGENT},
            timeout=REQUEST_TIMEOUT,
        )
        if qid_resp.status_code != 200:
            print(f"SPARQL error (QID) for {name}: {qid_resp.status_code}")
            return None
        qid_results = qid_resp.json()["results"]["bindings"]
        if not qid_results:
            return None
        return qid_results[0]["item"]["value"].split('/')[-1]

    qid = get_qid(scientific_name)
    if not qid:
        # Try capitalized form
        cap_name = scientific_name[0].upper() + scientific_name[1:]
        qid = get_qid(cap_name)
    if not qid:
        print(f"No Q-ID found for {scientific_name}")
        return []

    # Step 2: Hierarchical taxon query using Q-ID
    query = f"""
    PREFIX wd: <http://www.wikidata.org/entity/>
    PREFIX wdt: <http://www.wikidata.org/prop/direct/>
    PREFIX wikibase: <http://wikiba.se/ontology#>
    PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

    SELECT ?rankLabel ?taxonLabel (SAMPLE(?taxonScientificName) AS ?taxonScientificName)
           (SAMPLE(?iucnLabel) AS ?iucnStatusLabel)
           (SAMPLE(?rangeMapFile) AS ?rangeMapFile)
           (SAMPLE(?animalImageFile) AS ?animalImageFile)
    WHERE {{
      wd:{qid} wdt:P171* ?taxon .
      ?taxon wdt:P105 ?rank .
      OPTIONAL {{ ?taxon wdt:P225 ?taxonScientificName. }}
      OPTIONAL {{
        wd:{qid} wdt:P141 ?iucnStatus.
        ?iucnStatus rdfs:label ?iucnLabel FILTER(LANG(?iucnLabel)="en")
      }}
      OPTIONAL {{ wd:{qid} wdt:P181 ?rangeMapFile. }}
      OPTIONAL {{ wd:{qid} wdt:P18 ?animalImageFile. }}
      SERVICE wikibase:label {{
        bd:serviceParam wikibase:language "en".
        ?taxon rdfs:label ?taxonLabel.
        ?rank rdfs:label ?rankLabel.
      }}
    }}
    GROUP BY ?rankLabel ?taxonLabel
    ORDER BY ?rankLabel
    """

    resp = session.get(
        SPARQL_ENDPOINT,
        params={"query": query, "format": "json"},
        headers={"User-Agent": USER_AGENT},
        timeout=REQUEST_TIMEOUT,
    )
    if resp.status_code == 200:
        return resp.json()["results"]["bindings"]
    else:
        print(f"SPARQL error for {scientific_name}: {resp.status_code}")
        return []

def get_wikipedia_summary(title):
    url = WIKI_SUMMARY_ENDPOINT + title.replace(' ', '_')
    resp = session.get(url, headers={"User-Agent": USER_AGENT}, timeout=REQUEST_TIMEOUT)
    if resp.status_code == 200:
        return resp.json().get('extract', '')
    return None

def download_commons_image(filename):
    if not filename:
        return None
    url = COMMONS_FILEPATH + filename
    resp = session.get(url, stream=True, headers={"User-Agent": USER_AGENT}, timeout=REQUEST_TIMEOUT)
    if resp.status_code == 200:
        img_path = os.path.join(IMAGES_DIR, filename)
        with open(img_path, "wb") as f:
            for chunk in resp.iter_content(1024):
                f.write(chunk)
        return img_path
    return None

def build_classification(parent_chain):
    # parent_chain: list of dicts with rank and label
    ranks = ["kingdom", "phylum", "class", "order", "family", "genus", "species"]
    classification = {r: "" for r in ranks}
    for node in parent_chain:
        rank = node.get("taxonRankLabel", {}).get("value", "").lower()
        label = node.get("itemLabel", {}).get("value", "")
        if rank in classification:
            classification[rank] = label
    return classification

def snake_case(name):
    return name.replace(" ", "_").replace("-", "_").lower()


def main():
    parser = argparse.ArgumentParser(description="Parse species data from Wikidata/Wikipedia")
    parser.add_argument("--number_parse", type=int, default=None, help="Number of species to parse (default: all)")
    parser.add_argument("--input_species_json", default=None, help="Path to an existing species.json to reparse text only")
    parser.add_argument("--species_list_json", default=None, help="Path to a species list JSON (genus/species or species objects)")
    parser.add_argument("--output_species_json", default=OUTPUT_JSON_PATH, help="Output species.json path")
    parser.add_argument("--text_only", action="store_true", help="Only reparse text fields; keep existing images")
    parser.add_argument("--skip_images", action="store_true", help="Skip all image downloads")
    parser.add_argument("--start_index", type=int, default=0, help="Start index for resuming a long run")
    args = parser.parse_args()

    # Ensure new image directories exist
    SPECIES_IMAGES_DIR = os.path.join("assets", "species-images")
    RANGE_IMAGES_DIR = os.path.join("assets", "range-images")
    Path(SPECIES_IMAGES_DIR).mkdir(parents=True, exist_ok=True)
    Path(RANGE_IMAGES_DIR).mkdir(parents=True, exist_ok=True)
    ensure_dirs()
    if args.species_list_json:
        list_path = args.species_list_json
        if os.path.isdir(list_path):
            list_path = os.path.join(list_path, "species.json")
        species_list = load_species_list(list_path)
        existing_species = None
    elif args.input_species_json:
        input_path = args.input_species_json
        if os.path.isdir(input_path):
            input_path = os.path.join(input_path, "species.json")
        with open(input_path, "r") as f:
            existing_species = json.load(f)
        species_list = _normalize_species_list(existing_species)
    else:
        existing_species = None
        species_list = load_species_list()
    if args.number_parse:
        species_list = species_list[:args.number_parse]
    results = []
    failed = []
    summary_cache = {}
    higher_taxa_list = []
    higher_taxa_index = {}
    for idx, entry in enumerate(tqdm(species_list, desc="Parsing species")):
        if idx < args.start_index:
            continue
        genus = entry.get("genus", "")
        species = entry.get("species", "")
        scientific_name = f"{genus} {species}"
        print(f"Processing: {scientific_name}")
        try:
            try:
                sparql_data = sparql_query(scientific_name)
            except Exception as e:
                print(f"SPARQL request failed for {scientific_name}: {e}")
                failed.append(scientific_name)
                continue
            if not sparql_data:
                print(f"No SPARQL data for {scientific_name}")
                failed.append(scientific_name)
                continue

            # Parse new SPARQL results
            classification = {r: "" for r in ["kingdom", "phylum", "class", "order", "family", "genus", "species"]}
            iucn_status = None
            range_map_file = None
            animal_image_file = None
            common_name = None

            # Helper: fallback mapping for common to scientific names
           
            # Track scientific names for each rank
            scientific_classification = {r: "" for r in ["kingdom", "phylum", "class", "order", "family", "genus", "species"]}
            for row in sparql_data:
                rank = row.get("rankLabel", {}).get("value", "").lower()
                scientific_label = row.get("taxonScientificName", {}).get("value") or row.get("taxonLabel", {}).get("value", "")
                # Use fallback mapping for known ranks
                if rank in scientific_classification:
                    # Always use scientific name for classification
                    if rank == "species":
                        # For species, use binomial name
                        scientific_classification[rank] = scientific_name
                    else:
                        scientific_classification[rank] = scientific_label
                # Get IUCN status, range map, and animal image from any row that has them
                if not iucn_status:
                    iucn_status = row.get("iucnStatusLabel", {}).get("value", None)
                if not range_map_file:
                    range_map_file = row.get("rangeMapFile", {}).get("value", None)
                if not animal_image_file:
                    animal_image_file = row.get("animalImageFile", {}).get("value", None)

            # Use scientific_classification for output
            # For species, save only the epithet (second word)
            if scientific_classification["species"]:
                species_binomial = scientific_classification["species"]
                if " " in species_binomial:
                    scientific_classification["species"] = species_binomial.split(" ", 1)[1]
            classification = scientific_classification

            # Get filenames from SPARQL results
            range_map_filename = range_map_file.split('/')[-1] if range_map_file else None
            animal_image_filename = animal_image_file.split('/')[-1] if animal_image_file else None

            genus_species = snake_case(scientific_name)
            animal_img_filename = f"{genus_species}.jpg"
            range_img_ext = range_map_filename.split('.')[-1] if range_map_filename and '.' in range_map_filename else 'img'
            range_img_filename = f"{genus_species}_range.{range_img_ext}"

            # Get species common name and summary from Wikipedia summary API
            wiki_api_url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{scientific_name.replace(' ', '_')}"
            resp = requests.get(wiki_api_url, headers={"User-Agent": USER_AGENT})
            summary = None
            common_name = None
            if resp.status_code == 200:
                data = resp.json()
                raw_common_name = data.get('displaytitle') or data.get('title')
                import re
                common_name = re.sub(r'<[^>]+>', '', raw_common_name) if raw_common_name else None
                summary = data.get('extract', None)

            import re
            def strip_html_tags(text):
                if not text:
                    return text
                return re.sub(r'<[^>]+>', '', text)

            # If species summary is missing or empty, fallback to higher taxon summary
            if not summary:
                for rank in ["genus", "family", "order", "class"]:
                    taxon = classification.get(rank, None)
                    if taxon:
                        if taxon in summary_cache:
                            summary = summary_cache[taxon]
                        else:
                            summary = get_wikipedia_summary(taxon)
                            summary_cache[taxon] = summary
                        if summary:
                            break

            higher_taxa_refs = []
            for rank in ["genus", "family", "order", "class"]:
                taxon = classification.get(rank, None)
                if taxon:
                    if taxon in higher_taxa_index:
                        taxon_id = higher_taxa_index[taxon]
                    else:
                        if taxon in summary_cache:
                            taxon_summary = summary_cache[taxon]
                        else:
                            taxon_summary = get_wikipedia_summary(taxon)
                            summary_cache[taxon] = taxon_summary
                        wiki_api_url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{taxon.replace(' ', '_')}"
                        resp = requests.get(wiki_api_url, headers={"User-Agent": USER_AGENT})
                        taxon_common_name = None
                        if resp.status_code == 200:
                            data = resp.json()
                            raw_common_name = data.get('displaytitle') or data.get('title')
                            taxon_common_name = strip_html_tags(raw_common_name) if raw_common_name else None
                        taxon_entry = {
                            "scientific_name": taxon,
                            "common_name": taxon_common_name,
                            "rank": rank,
                            "description": taxon_summary
                        }
                        taxon_id = len(higher_taxa_list)
                        higher_taxa_list.append(taxon_entry)
                        higher_taxa_index[taxon] = taxon_id
                    higher_taxa_refs.append({"name": taxon, "rank": rank})

            # Download and rename animal image to species-images
            animal_image_path = None
            if animal_image_filename and not args.skip_images and not args.text_only:
                temp_path = download_commons_image(animal_image_filename)
                if temp_path:
                    # Convert to jpg if not already
                    if not temp_path.lower().endswith('.jpg'):
                        try:
                            from PIL import Image
                            im = Image.open(temp_path)
                            jpg_path = os.path.join(SPECIES_IMAGES_DIR, animal_img_filename)
                            im.convert('RGB').save(jpg_path, 'JPEG')
                            os.remove(temp_path)
                            animal_image_path = jpg_path
                        except Exception as e:
                            print(f"Error converting {temp_path} to jpg: {e}")
                            animal_image_path = temp_path
                    else:
                        new_path = os.path.join(SPECIES_IMAGES_DIR, animal_img_filename)
                        os.rename(temp_path, new_path)
                        animal_image_path = new_path
            animal_image_rel_path = os.path.relpath(animal_image_path, '.') if animal_image_path else None

            # Download and rename range map image to range-images
            image_path = None
            if range_map_filename and not args.skip_images and not args.text_only:
                temp_path = download_commons_image(range_map_filename)
                if temp_path:
                    new_path = os.path.join(RANGE_IMAGES_DIR, range_img_filename)
                    os.rename(temp_path, new_path)
                    image_path = new_path
            image_rel_path = os.path.relpath(image_path, '.') if image_path else None

            result = {
                "id": genus_species if not args.input_species_json else entry.get("_existing", {}).get("id", genus_species),
                "common_name": common_name,
                "scientific_name": scientific_name,
                "iucn_status": iucn_status,
                "classification": classification,
                "summary": summary,
            }
            if args.input_species_json and entry.get("_existing"):
                existing = entry["_existing"]
                if args.text_only:
                    result["image"] = existing.get("image")
                    result["range_map"] = existing.get("range_map")
                    result["animal_image"] = existing.get("animal_image")
            results.append(result)
        except Exception as e:
            print(f"Failed to process {scientific_name}: {e}")
            failed.append(scientific_name)
        time.sleep(RATE_LIMIT)
        time.sleep(RATE_LIMIT)

        # Save every 5
        if (idx + 1) % 5 == 0:
            with open(args.output_species_json, "w") as f:
                json.dump(results, f, indent=2)
            with open("assets/data/failed.json", "w") as f:
                json.dump(failed, f, indent=2)
            with open(os.path.join(DATA_DIR, "taxa.json"), "w") as f:
                json.dump(higher_taxa_list, f, indent=2)

    # Final save
    # Save all species as a single array for Flutter compatibility
    with open(args.output_species_json, "w") as f:
        json.dump(results, f, indent=2)
    # Save higher taxa as a single array for Flutter compatibility
    with open(os.path.join(DATA_DIR, "taxa-hi.json"), "w") as f:
        json.dump(higher_taxa_list, f, indent=2)
    # Save failed as before
    with open(os.path.join(DATA_DIR, "failed.json"), "w") as f:
        json.dump(failed, f, indent=2)

if __name__ == "__main__":
    main()
