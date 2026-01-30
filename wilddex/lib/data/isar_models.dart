import 'package:isar/isar.dart';

part 'isar_models.g.dart';

@collection
class SpeciesEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String speciesId;
  late String commonName;
  late String scientificName;
  late String summary;
  String? iucnStatus;

  String? kingdomId;
  String? phylumId;
  String? classId;
  String? orderId;
  String? familyId;
  String? genusId;
  String? speciesTaxonId;
}

@collection
class TaxaEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String taxonId;
  late String rank;
  late String name;
  String? commonName;
  String? scientificName;
  String? description;
  String? parentId;
}

@collection
class MetaEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String key;
  late String value;
}
