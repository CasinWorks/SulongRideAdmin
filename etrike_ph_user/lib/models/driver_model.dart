import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Driver row from `drivers`.
// TODO: VERIFY DATA SHAPE — confirm columns match Supabase `drivers`.
class DriverModel {
  const DriverModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.profilePhotoUrl,
    this.trikePlateNumber,
    this.trikeModel,
    this.isAvailable = false,
    this.isOnline = false,
    this.currentLat,
    this.currentLng,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? profilePhotoUrl;
  final String? trikePlateNumber;
  final String? trikeModel;
  final bool isAvailable;
  final bool isOnline;
  final double? currentLat;
  final double? currentLng;

  LatLng? get latLng {
    if (currentLat == null || currentLng == null) return null;
    return LatLng(currentLat!, currentLng!);
  }

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      trikePlateNumber: json['trike_plate_number'] as String?,
      trikeModel: json['trike_model'] as String?,
      isAvailable: json['is_available'] as bool? ?? false,
      isOnline: json['is_online'] as bool? ?? false,
      currentLat: (json['current_lat'] as num?)?.toDouble(),
      currentLng: (json['current_lng'] as num?)?.toDouble(),
    );
  }
}
