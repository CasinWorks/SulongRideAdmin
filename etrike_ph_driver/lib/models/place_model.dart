class PlaceModel {
  const PlaceModel({
    required this.id,
    required this.slug,
    required this.name,
    this.displayName,
    this.isActive = true,
  });

  final String id;
  final String slug;
  final String name;
  final String? displayName;
  final bool isActive;

  String get label =>
      (displayName?.trim().isNotEmpty == true) ? displayName!.trim() : name;

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
