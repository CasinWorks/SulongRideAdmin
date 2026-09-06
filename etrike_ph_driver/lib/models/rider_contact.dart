class RiderContact {
  const RiderContact({
    required this.fullName,
    this.phone,
    this.profilePhotoUrl,
  });

  final String fullName;
  final String? phone;
  final String? profilePhotoUrl;

  String get initial {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'P';
    return trimmed[0].toUpperCase();
  }

  factory RiderContact.fromJson(Map<String, dynamic> json) {
    return RiderContact(
      fullName: (json['full_name'] as String?)?.trim().isNotEmpty == true
          ? (json['full_name'] as String).trim()
          : 'Passenger',
      phone: (json['phone'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['phone'] as String).trim(),
      profilePhotoUrl: (json['profile_photo_url'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['profile_photo_url'] as String).trim(),
    );
  }
}
