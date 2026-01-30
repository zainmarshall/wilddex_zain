# JSON Files
- Geofence_base.json is a file from the model that contains all the possible countries for each species, which we can use to get the speceis list.  
- specieslist.json is the extracted list of species the model knows
- genus_species.json is a nicley formated version of species list with just the genus and species
- missing.json are speceis from genus_species.json we haven't parsed yet.

# Python Files
- extract.py converts specieslist.json into genus_species
- missing.py compares our parsed data in our output to genus species and outputs a file of the missing species in missing.json