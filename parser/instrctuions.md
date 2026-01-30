# Species Data Pipeline — Replace iNaturalist with Wikidata + Wikipedia

This document outlines how to build a Python pipeline that:
- Fetches structured species data (IUCN status, range maps, taxonomy) via **Wikidata SPARQL API**
- Retrieves text summaries of species and higher taxa (family, order, class) via **Wikipedia REST/API**
- Downloads species images from Wikimedia Commons (via Wikidata file links)


The list of speicies to parse are in SpeciesList/genus_species.json. From that file you an save all of the higher taxonomy we find n a datastructure, and then parse that later.
---

## 1. Requirements & APIs

### 1.1 Wikidata (SPARQL endpoint)
- Property **P141** = IUCN conservation status  
- Property **P181** = range map image file  
- Property **P225** = scientific name  
- Property **P105** = taxon rank  
- Property **P171** = parent taxon  
- Query via `https://query.wikidata.org/sparql`

### 1.2 Wikipedia REST API
- Summary endpoint:  
  `GET https://en.wikipedia.org/api/rest_v1/page/summary/{title}`
- MediaWiki Action API for longer extracts / family/order pages, if needed:
  `GET https://en.wikipedia.org/w/api.php?action=query&prop=extracts&exintro&explaintext&titles={title}&format=json` :contentReference[oaicite:1]{index=1}

### 1.3 Wikimedia Commons
- Direct file URL:  
  `https://commons.wikimedia.org/wiki/Special:FilePath/{filename}`  
  to download P181 or P18 images :contentReference[oaicite:2]{index=2}

---

## 2. Pipeline Outline

### 2.1 Species-level SPARQL query

For each scientific name (e.g. `"Panthera leo"`), run:

```sparql
SELECT ?item ?iucnLabel ?rangeMap ?parent ?parentLabel WHERE {
  ?item wdt:P225 "Panthera leo".
  OPTIONAL { ?item wdt:P141 ?iucn. }
  OPTIONAL { ?item wdt:P181 ?rangeMap. }
  OPTIONAL { ?item wdt:P171 ?parent. }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
Extract item’s Q‑ID, IUCN status, range image filename, parent taxon.

Walk up P171 to collect higher taxonomic ranks if needed 
Wikidata
TechRadar
.

2.2 Wikipedia summary retrieval
For each taxon (species, genus, family, order, class):

python
Copy
Edit
def get_summary(title):
    url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{title.replace(' ', '_')}"
    resp = requests.get(url, headers={'User-Agent':'MyApp/1.0'})
    return resp.json().get('extract', '') if resp.status_code == 200 else None
Use Wikipedia REST summary for the main text summary.

For more detailed intros, fall back to Action API with exintro & explaintext 
Wikidata
+1
Wikidata
+1
MediaWiki
+3
Stack Overflow
+3
MediaWiki
+3
.

2.3 Downloading images
If SPARQL returns a filename in rangeMap, create an image URL:

python
Copy
Edit
img_url = f"https://commons.wikimedia.org/wiki/Special:FilePath/{filename}"
Download with requests and save locally.

3. JSON Structure
Each species JSON record:

json
Copy
Edit
{
  "id": "<scientific_name_snakecase>",
  "common_name": "<optional>",
  "scientific_name": "Panthera leo",
  "iucn_status": "Vulnerable",
  "range_map": "assets/images/<filename>.jpg",
  "classification": {
    "kingdom": "...",
    "phylum": "...",
    "class": "...",
    "order": "...",
    "family": "...",
    "genus": "Panthera",
    "species": "leo"
  },
  "summary": "<Wikipedia summary text>",
  "higher_taxa_summaries": {
    "genus": "<text>",
    "family": "<text>",
    // etc.
  },
  "image": "assets/images/<filename>.jpg"
}
4. Workflow Logic
Initialize directories (images + data folders)

For each species name:

Run SPARQL query → get Wikidata Q‑item, taxonomy, IUCN status, range map

Fetch Wikipedia summary for species

For each higher-rank taxon (e.g. family, order):

Get Wikipedia summary

Download range map/image if any

Build JSON entry

Save to species.json incrementally with error logging/retries

5. Tips & Best Practices
Respect query rate limits, add small delays between SPARQL and REST calls

Send a proper User-Agent header to all Wikimedia endpoints 
Reddit
+11
MediaWiki
+11
MediaWiki
+11
Wikidata

Handle missing data gracefully (e.g. missing IUCN, missing Wikipedia page)

Cache previously fetched Q‑IDs and summaries to minimize repeated lookups

Log errors and skip problematic entries (e.g. ambiguous titles)

6. Example Code Snippets
python
Copy
Edit
# SPARQL request
resp = requests.get("https://query.wikidata.org/sparql",
                    params={'query': sparql}, headers={'User-Agent': 'MyApp/0.1'})
data = resp.json()

# Wikipedia summary
summary = get_summary("Panthera leo")
python
Copy
Edit
# Construct classification from parent chain
classification = {}
current = species_item
while current_rank not in ["family","class","order","kingdom"]:
    classification[current_rank] = current_label
    current = get_parent_taxon(current)
✅ Why this works
Wikidata provides structured, reusable taxonomic and conservation data at scale 
Wikidata

Wikipedia REST API gives fast, clean text summaries, optimized for developer use 
Medium
+1
TechRadar
+1

Combining both yields structured + human‑readable data without heavy scraping.



# Output JSON Format:
[
  {
    "id": "Amblysomus_corriae",
    "common_name": "Fynbos Golden Mole",
    "scientific_name": "Amblysomus corriae",
    "classification": {
      "kingdom": "Animalia",
      "phylum": "Chordata",
      "class": "Mammalia",
      "order": "Afrosoricida",
      "family": "Chrysochloridae",
      "genus": "Amblysomus",
      "species": "corriae"
    },
    "facts": [
      "The <b>fynbos golden mole</b> (<i>Amblysomus corriae</i>) is a species of mammal in the golden mole family, Chrysochloridae. It is endemic to South Africa."
    ],
    "biomes": [],
    "iucn_status": null
  },
  {
    "id": "Amblysomus_hottentotus",
    "common_name": "Hottentot Golden Mole",
    "scientific_name": "Amblysomus hottentotus",
    "classification": {
      "kingdom": "Animalia",
      "phylum": "Chordata",
      "class": "Mammalia",
      "order": "Afrosoricida",
      "family": "Chrysochloridae",
      "genus": "Amblysomus",
      "species": "hottentotus"
    },
    "facts": [
      "The <b>Hottentot golden mole</b> (<i>Amblysomus hottentotus</i>) is a species of mammal in the golden mole family, Chrysochloridae. It is found in South Africa, Swaziland, and possibly Lesotho. Its natural habitats are temperate forests, subtropical or tropical dry forest, subtropical or tropical moist lowland forest, dry savanna, moist savanna, subtropical or tropical dry shrubland, Mediterranean-type shrubby vegetation, temperate grassland, subtropical or tropical dry lowland grassland, subtropical or tropical high-altitude grassland, sandy shores, arable land, pastureland, plantations, rural..."
    ],
    "biomes": [],
    "iucn_status": null
  },

  