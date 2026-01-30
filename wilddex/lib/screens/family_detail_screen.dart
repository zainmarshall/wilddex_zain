import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_data.dart';
import '../models/family.dart';
import '../models/species.dart';
import '../widgets/mini_species_card.dart';
import '../models/taxa.dart';
import 'animal_detail_screen.dart';
import '../utils/user_data_provider.dart';

class FamilyDetailScreen extends StatelessWidget {
  final Family family;
  final List<Taxa> taxaList;
  final List<Species> allSpecies;
  final String highlightQuery;

  const FamilyDetailScreen({
    super.key,
    required this.family,
    required this.taxaList,
    required this.allSpecies,
    this.highlightQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserDataProvider>(
      builder: (context, userData, child) {
        final appData = Provider.of<AppData>(context, listen: false);
        final discoveredIds = userData.discoveredSpeciesIds;
        final updatedSpecies = family.species
            .map((s) => s.copyWith(discovered: discoveredIds.contains(s.id)))
            .toList();
        // Sort species: discovered first, then by name
        updatedSpecies.sort((a, b) {
          if (a.isDiscovered != b.isDiscovered) {
            return b.isDiscovered ? 1 : -1;
          }
          return a.name.compareTo(b.name);
        });
        final displaySpecies = _moveMatchesToTop(updatedSpecies, highlightQuery);
        final updatedFamily = Family(
          name: family.name,
          scientificName: family.scientificName,
          description: family.description,
          species: displaySpecies,
          image: family.image,
        );

        // Find family summary and common name from taxa index
        final keyBySci =
            'family|${family.scientificName.toLowerCase()}';
        final keyByCommon = 'family|${family.name.toLowerCase()}';
        final familyTaxa =
            appData.taxaByRankName[keyBySci] ??
            appData.taxaByRankName[keyByCommon];
        final familyCommonName = familyTaxa?.commonName;

        return Scaffold(
          appBar: AppBar(
            title: Text(updatedFamily.name),
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Theme.of(context).colorScheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        familyCommonName ?? updatedFamily.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        updatedFamily.scientificName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                      const SizedBox(height: 8),
                      // Show family summary from taxa.json if available
                      if (familyTaxa != null) ...[
                        Text(
                          familyTaxa.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        Text(
                          family.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: family.discoveryProgress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${updatedFamily.discoveredSpeciesCount}/${updatedFamily.species.length} species discovered',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final species = updatedFamily.species[index];
                      final maxHero = updatedFamily.species.length < 4 ? updatedFamily.species.length : 4;
                      final useHero = index < maxHero;
                      final heroIndex = useHero ? index : null;
                      final isDiscovered = species.isDiscovered;
                      final BorderRadius cardRadius =
                          const BorderRadius.all(Radius.circular(20.0));
                      return Card(
                        color: Colors.white,
                        elevation: 10,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: cardRadius,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: MiniSpeciesCard(
                                  species: species,
                                  useHero: useHero,
                                  heroIndex: heroIndex,
                                  highlight: _matchesQuery(species, highlightQuery),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AnimalDetailScreen(
                                          species: species,
                                          taxaList: taxaList,
                                          allSpecies: allSpecies,
                                        ),
                                      ),
                                    );
                                  },
                                  roundTopCorners: isDiscovered,
                                  borderRadius: cardRadius,
                                ),
                              ),
                              if (isDiscovered) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
                                  child: Text(
                                    species.name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0, left: 4.0, right: 4.0),
                                  child: Text(
                                    species.scientificName,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: updatedFamily.species.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Species> _moveMatchesToTop(List<Species> species, String query) {
    if (query.isEmpty) return species;
    final lower = query.toLowerCase();
    final matches = <Species>[];
    final rest = <Species>[];
    for (final s in species) {
      if (_matchesQuery(s, lower)) {
        matches.add(s);
      } else {
        rest.add(s);
      }
    }
    return [...matches, ...rest];
  }

  bool _matchesQuery(Species species, String lowerQuery) {
    if (lowerQuery.isEmpty) return false;
    return species.name.toLowerCase().contains(lowerQuery) ||
        species.scientificName.toLowerCase().contains(lowerQuery);
  }
}
