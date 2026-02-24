/// GeocodingService — platform-native geocoding wrapper.
///
/// Uses the `geocoding` package to resolve free-text addresses
/// into structured address components. Falls back gracefully
/// when geocoding is unavailable or fails.
library;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

class GeocodingService {
  GeocodingService._();

  /// Resolve a free-text address into structured components.
  ///
  /// Returns a map with keys: `formatted`, `street`, `city`,
  /// `state`, `country`, `postalCode`, `lat`, `lng`.
  ///
  /// On failure, returns `{"formatted": freeText}` so the form
  /// still works without geocoding.
  static Future<Map<String, dynamic>> resolveAddress(String freeText) async {
    if (freeText.trim().isEmpty) {
      return {'formatted': freeText};
    }

    try {
      final locations = await locationFromAddress(freeText);
      if (locations.isEmpty) {
        return {'formatted': freeText};
      }

      final location = locations.first;

      // Reverse geocode from coordinates to get structured address
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isEmpty) {
        return {
          'formatted': freeText,
          'lat': location.latitude,
          'lng': location.longitude,
        };
      }

      final place = placemarks.first;

      final result = <String, dynamic>{
        'formatted': _buildFormattedAddress(place),
        'street': [place.thoroughfare, place.subThoroughfare]
            .where((s) => s != null && s.isNotEmpty)
            .join(' '),
        'city': place.locality ?? '',
        'state': place.administrativeArea ?? '',
        'country': place.country ?? '',
        'postalCode': place.postalCode ?? '',
        'lat': location.latitude,
        'lng': location.longitude,
      };

      if (kDebugMode) {
        print('📍 Geocoded "$freeText" → ${result['formatted']}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('📍 Geocoding failed for "$freeText": $e');
      }
      return {'formatted': freeText};
    }
  }

  static String _buildFormattedAddress(Placemark place) {
    final parts = <String>[
      if (place.thoroughfare?.isNotEmpty == true) place.thoroughfare!,
      if (place.subThoroughfare?.isNotEmpty == true) place.subThoroughfare!,
      if (place.subLocality?.isNotEmpty == true) place.subLocality!,
      if (place.locality?.isNotEmpty == true) place.locality!,
      if (place.administrativeArea?.isNotEmpty == true)
        place.administrativeArea!,
      if (place.postalCode?.isNotEmpty == true) place.postalCode!,
      if (place.country?.isNotEmpty == true) place.country!,
    ];
    return parts.join(', ');
  }
}
