import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class EcoPaymentCard {
  const EcoPaymentCard({
    required this.id,
    required this.brand,
    required this.last4,
    this.expiry = '12/29',
  });

  final String id;
  final String brand;
  final String last4;
  final String expiry;

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'last4': last4,
        'expiry': expiry,
      };

  factory EcoPaymentCard.fromJson(Map<String, dynamic> json) {
    return EcoPaymentCard(
      id: json['id'] as String,
      brand: json['brand'] as String? ?? 'visa',
      last4: json['last4'] as String? ?? '0000',
      expiry: json['expiry'] as String? ?? '12/29',
    );
  }
}

class EcoTripRating {
  const EcoTripRating({required this.rating, this.review});

  final int rating;
  final String? review;

  Map<String, dynamic> toJson() => {'rating': rating, 'review': review};

  factory EcoTripRating.fromJson(Map<String, dynamic> json) {
    return EcoTripRating(
      rating: json['rating'] as int? ?? 5,
      review: json['review'] as String?,
    );
  }
}

/// Local eco gamification + settings (mirrors design-reference localStorage).
abstract final class EcoLocalStore {
  static const _co2Key = 'eco_saved_co2';
  static const _ridesKey = 'eco_green_rides';
  static const _walletKey = 'eco_wallet_balance';
  static const _pinKey = 'eco_security_pin';
  static const _pushKey = 'eco_push_notifications';
  static const _gpsKey = 'eco_high_accuracy_gps';
  static const _vehicleKey = 'eco_default_vehicle';
  static const _homeKey = 'eco_home_address';
  static const _workKey = 'eco_work_address';
  static const _cardsKey = 'eco_payment_cards';
  static const _ratingsKey = 'eco_trip_ratings';
  static const _pendingRatingKey = 'eco_pending_rating_trip_id';
  static const _onboardingKey = 'eco_onboarding_completed';

  static Future<double> co2Saved() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_co2Key) ?? 4.8;
  }

  static Future<void> addCo2Saved(double kg) async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getDouble(_co2Key) ?? 4.8) + kg;
    await prefs.setDouble(_co2Key, next);
  }

  static Future<int> greenRides() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_ridesKey) ?? 12;
  }

  static Future<void> incrementGreenRides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ridesKey, (prefs.getInt(_ridesKey) ?? 12) + 1);
    await addCo2Saved(0.42);
  }

  static Future<double> walletBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_walletKey) ?? 250;
  }

  static Future<void> setWalletBalance(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_walletKey, value);
  }

  static Future<String> homeAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_homeKey) ??
        'Blk 12 Lot 5, Carmona Estates, Cavite';
  }

  static Future<void> setHomeAddress(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_homeKey, value);
  }

  static Future<String> workAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_workKey) ??
        'Carmona Public Market, Cavite';
  }

  static Future<void> setWorkAddress(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workKey, value);
  }

  static Future<List<EcoPaymentCard>> paymentCards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cardsKey);
    if (raw == null || raw.isEmpty) {
      return const [
        EcoPaymentCard(id: 'card-default', brand: 'visa', last4: '4242'),
      ];
    }
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => EcoPaymentCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> savePaymentCards(List<EcoPaymentCard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cardsKey,
      jsonEncode(cards.map((c) => c.toJson()).toList()),
    );
  }

  static Future<Map<String, EcoTripRating>> tripRatings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ratingsKey);
    if (raw == null || raw.isEmpty) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map(
      (k, v) => MapEntry(k, EcoTripRating.fromJson(v as Map<String, dynamic>)),
    );
  }

  static Future<EcoTripRating?> ratingForTrip(String tripId) async {
    final all = await tripRatings();
    return all[tripId];
  }

  static Future<void> saveTripRating({
    required String tripId,
    required int rating,
    String? review,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await tripRatings();
    all[tripId] = EcoTripRating(rating: rating, review: review);
    await prefs.setString(
      _ratingsKey,
      jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await clearPendingRatingTrip();
  }

  static Future<String?> pendingRatingTripId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingRatingKey);
  }

  static Future<void> setPendingRatingTrip(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingRatingKey, tripId);
  }

  static Future<void> clearPendingRatingTrip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingRatingKey);
  }

  static Future<bool> securityPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinKey) ?? false;
  }

  static Future<void> setSecurityPinEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pinKey, value);
  }

  static Future<bool> pushNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushKey) ?? true;
  }

  static Future<void> setPushNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushKey, value);
  }

  static Future<bool> highAccuracyGps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_gpsKey) ?? true;
  }

  static Future<void> setHighAccuracyGps(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gpsKey, value);
  }

  static Future<String> defaultVehicle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_vehicleKey) ?? 'bike';
  }

  static Future<void> setDefaultVehicle(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vehicleKey, id);
  }

  static Future<bool> onboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  static Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, value);
  }

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _co2Key,
      _ridesKey,
      _walletKey,
      _pinKey,
      _pushKey,
      _gpsKey,
      _vehicleKey,
      _homeKey,
      _workKey,
      _cardsKey,
      _ratingsKey,
      _pendingRatingKey,
      _onboardingKey,
    ]) {
      await prefs.remove(key);
    }
  }
}
