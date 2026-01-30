import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wilddex/theme/colors.dart';
import '../models/species.dart';
import '../models/taxa.dart';
import '../models/family.dart';
import '../widgets/family_card.dart';
import '../widgets/mini_species_card.dart';
import 'family_detail_screen.dart';
import 'animal_detail_screen.dart';
import '../utils/user_data_provider.dart';

class DexScreen extends StatefulWidget {
  final List<Species> speciesList;
  final List<Taxa> taxaList;
  const DexScreen({super.key, required this.speciesList, required this.taxaList});

  @override
  State<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends State<DexScreen> {
  List<Family> _baseFamilies = [];
  String _searchQuery = '';
  String _cardType = 'family'; // 'family' or 'species'
  bool _showDiscoveredOnly = false;
  int _lastSpeciesCount = 0;
  List<Family> _displayFamilies = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lastSpeciesCount == widget.speciesList.length) return;
    final Map<String, List<Species>> familyGroups = {};
    for (final species in widget.speciesList) {
      final family = species.classification?.family ?? 'Unknown';
      familyGroups.putIfAbsent(family, () => []).add(species);
    }
    _baseFamilies = familyGroups.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => Family.fromSpeciesList(entry.value))
        .toList()
      ..sort((a, b) {
        final aDiscovered = a.species.any((s) => s.isDiscovered);
        final bDiscovered = b.species.any((s) => s.isDiscovered);
        if (aDiscovered != bDiscovered) {
          return bDiscovered ? 1 : -1;
        }
        return a.name.compareTo(b.name);
      });
    _lastSpeciesCount = widget.speciesList.length;
  }

  @override
  Widget build(BuildContext context) {
    // No loading state needed
    return Consumer<UserDataProvider>(
      builder: (context, userData, child) {
        final discoveredIds = userData.discoveredSpeciesIds;
        // Update discovered state for each species
        final families = _baseFamilies.map((family) {
          final updatedSpecies = family.species
              .map((s) => s.copyWith(discovered: discoveredIds.contains(s.id)))
              .toList(growable: false);
          return Family(
            name: family.name,
            scientificName: family.scientificName,
            description: family.description,
            species: updatedSpecies,
            image: family.image,
          );
        }).toList();

        final lowerQuery = _searchQuery.toLowerCase();
        final filteredFamilies = <Family>[];
        for (final family in families) {
          final familyMatches = lowerQuery.isEmpty ||
              family.name.toLowerCase().contains(lowerQuery) ||
              family.scientificName.toLowerCase().contains(lowerQuery) ||
              family.species.any(
                (s) =>
                    s.name.toLowerCase().contains(lowerQuery) ||
                    s.scientificName.toLowerCase().contains(lowerQuery),
              );

          if (!familyMatches) continue;
          if (_showDiscoveredOnly &&
              !family.species.any((s) => s.isDiscovered)) {
            continue;
          }

          filteredFamilies.add(family);
        }
        filteredFamilies.sort((a, b) {
          final aDiscovered = a.species.any((s) => s.isDiscovered);
          final bDiscovered = b.species.any((s) => s.isDiscovered);
          if (aDiscovered != bDiscovered) {
            return bDiscovered ? 1 : -1;
          }
          return a.name.compareTo(b.name);
        });

        // Group families by class
        final Map<String, List<Family>> classGroups = {};
        for (final family in filteredFamilies) {
          final className = family.species.isNotEmpty
              ? (family.species.first.classification?.className ?? 'Unknown')
              : 'Unknown';
          classGroups.putIfAbsent(className, () => []).add(family);
        }
        final sortedClassNames = classGroups.keys.toList()..sort();
        final flatSpecies = _cardType == 'species'
            ? _buildFilteredSpeciesList(
                families,
                lowerQuery,
                _showDiscoveredOnly,
              )
            : filteredFamilies
                .expand((family) => family.species)
                .toList(growable: false);
        _displayFamilies = filteredFamilies;

        // Summary at the top
        final foundCount = families.fold(
          0,
          (sum, fam) => sum + fam.species.where((s) => s.isDiscovered).length,
        );
        final totalCount =
            families.fold(0, (sum, fam) => sum + fam.species.length);
        return CustomScrollView(
          slivers: [
            const SliverAppBar(
              title: Text('WildDex'),
              floating: true,
            ),
            // Search, card type, filter bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search species...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        contentPadding: const EdgeInsets.all(8),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: _cardType,
                          items: const [
                            DropdownMenuItem(value: 'family', child: Text('Card Type: Family')),
                            DropdownMenuItem(value: 'species', child: Text('Card Type: Species')),
                          ],
                          onChanged: (val) => setState(() => _cardType = val ?? 'family'),
                        ),
                        const SizedBox(width: 16),
                        FilterChip(
                          label: const Text('Discovered Only'),
                          selectedColor: AppColors.accent,
                          selected: _showDiscoveredOnly,
                          onSelected: (val) => setState(() => _showDiscoveredOnly = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Summary at the top
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Text(
                  '$foundCount / $totalCount species found',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            // Families grouped by class
            if (_cardType == 'family')
              for (final className in sortedClassNames) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    child: Text(
                      className,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final fam = classGroups[className]![index];
                        return FamilyCard(
                          family: fam,
                          taxaList: widget.taxaList,
                          highlightQuery: _searchQuery,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FamilyDetailScreen(
                                  family: fam,
                                  taxaList: widget.taxaList,
                                  allSpecies: widget.speciesList,
                                  highlightQuery: _searchQuery,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: classGroups[className]!.length,
                    ),
                  ),
                ),
              ]
            else
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final species = flatSpecies[index];
                      return MiniSpeciesCard(
                        species: species,
                        useHero: true,
                        heroIndex: index,
                        highlight: _cardType == 'species' &&
                            _speciesMatchesQuery(species, lowerQuery),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AnimalDetailScreen(
                                species: species,
                                taxaList: widget.taxaList,
                                allSpecies: widget.speciesList,
                              ),
                            ),
                          );
                        },
                      );
                    },
                    childCount: flatSpecies.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Species> _buildFilteredSpeciesList(
    List<Family> families,
    String lowerQuery,
    bool discoveredOnly,
  ) {
    List<Species> allSpecies = families.expand((f) => f.species).toList();
    if (lowerQuery.isNotEmpty) {
      allSpecies = allSpecies
          .where((s) =>
              s.name.toLowerCase().contains(lowerQuery) ||
              s.scientificName.toLowerCase().contains(lowerQuery))
          .toList();
    }
    if (discoveredOnly) {
      allSpecies = allSpecies.where((s) => s.isDiscovered).toList();
    }
    allSpecies.sort((a, b) {
      if (a.isDiscovered != b.isDiscovered) {
        return b.isDiscovered ? 1 : -1;
      }
      return a.name.compareTo(b.name);
    });
    return allSpecies;
  }

  bool _speciesMatchesQuery(Species species, String lowerQuery) {
    if (lowerQuery.isEmpty) return false;
    return species.name.toLowerCase().contains(lowerQuery) ||
        species.scientificName.toLowerCase().contains(lowerQuery);
  }

  List<Species> _highlightedFamilySpecies(Family family, String lowerQuery) {
    if (lowerQuery.isEmpty) return family.species;
    final matches = family.species
        .where((s) => _speciesMatchesQuery(s, lowerQuery))
        .toList();
    if (matches.isEmpty) return family.species;
    final rest = family.species.where((s) => !matches.contains(s)).toList();
    return [...matches, ...rest];
  }
}
