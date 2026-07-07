/// Rider profile from `users`.
// TODO: VERIFY DATA SHAPE — confirm columns match Supabase `users`.
class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.profilePhotoUrl,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? profilePhotoUrl;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
    );
  }
}
