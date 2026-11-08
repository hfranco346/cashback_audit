import 'package:equatable/equatable.dart';

/// A "rubro": groups merchants and carries card reward rules.
class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    this.description,
    this.merchantCount = 0,
  });

  final String id;
  final String name;
  final String? description;
  final int merchantCount;

  @override
  List<Object?> get props => [id, name, description, merchantCount];
}

/// A shop assigned to the category it is expected to accrue under.
/// [keywords] are statement descriptors used to match statement lines.
class Merchant extends Equatable {
  const Merchant({
    required this.id,
    required this.name,
    required this.categoryId,
    this.keywords = const [],
  });

  final String id;
  final String name;
  final String categoryId;
  final List<String> keywords;

  @override
  List<Object?> get props => [id, name, categoryId, keywords];
}
