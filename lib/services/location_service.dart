import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Service for Google Maps APIs (Places, Distance Matrix, Geocoding)
class LocationService {
  // Use the same API key from AndroidManifest
  static const String _apiKey = 'AIzaSyByssOBUO2hCb_dcm4xJqYrn-5hhBzXdSE';

  /// Get place predictions for address autocomplete
  static Future<List<PlacePrediction>> getPlacePredictions(String input) async {
    if (input.isEmpty) return [];

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(input)}'
      '&components=country:in' // Restrict to India
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return (data['predictions'] as List)
              .map((p) => PlacePrediction.fromJson(p))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting place predictions: $e');
      return [];
    }
  }

  /// Get place details (lat/lng) from place ID
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&fields=geometry,formatted_address'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting place details: $e');
      return null;
    }
  }

  /// Geocode an address to get lat/lng
  static Future<LatLng?> geocodeAddress(String address) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=${Uri.encodeComponent(address)}'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error geocoding address: $e');
      return null;
    }
  }

  /// Calculate distance and duration between two points
  static Future<DistanceResult?> getDistanceMatrix({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
      '?origins=${origin.lat},${origin.lng}'
      '&destinations=${destination.lat},${destination.lng}'
      '&mode=driving'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final element = data['rows'][0]['elements'][0];
          if (element['status'] == 'OK') {
            return DistanceResult(
              distanceText: element['distance']['text'],
              distanceMeters: element['distance']['value'],
              durationText: element['duration']['text'],
              durationSeconds: element['duration']['value'],
            );
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting distance matrix: $e');
      return null;
    }
  }

  /// Calculate distances from one origin to multiple destinations
  static Future<List<DistanceResult>> getMultipleDistances({
    required LatLng origin,
    required List<LatLng> destinations,
  }) async {
    if (destinations.isEmpty) return [];

    final destinationsStr = destinations
        .map((d) => '${d.lat},${d.lng}')
        .join('|');

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
      '?origins=${origin.lat},${origin.lng}'
      '&destinations=$destinationsStr'
      '&mode=driving'
      '&key=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return (data['rows'][0]['elements'] as List).map((element) {
            if (element['status'] == 'OK') {
              return DistanceResult(
                distanceText: element['distance']['text'],
                distanceMeters: element['distance']['value'],
                durationText: element['duration']['text'],
                durationSeconds: element['duration']['value'],
              );
            }
            return DistanceResult.unknown();
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting multiple distances: $e');
      return [];
    }
  }
}

/// Simple LatLng class for coordinates
class LatLng {
  final double lat;
  final double lng;

  LatLng(this.lat, this.lng);

  @override
  String toString() => 'LatLng($lat, $lng)';
}

/// Place prediction from autocomplete
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] ?? {};
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structured['main_text'] ?? '',
      secondaryText: structured['secondary_text'] ?? '',
    );
  }
}

/// Place details with coordinates
class PlaceDetails {
  final LatLng location;
  final String formattedAddress;

  PlaceDetails({required this.location, required this.formattedAddress});

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry']['location'];
    return PlaceDetails(
      location: LatLng(geometry['lat'], geometry['lng']),
      formattedAddress: json['formatted_address'] ?? '',
    );
  }
}

/// Distance and duration result
class DistanceResult {
  final String distanceText;
  final int distanceMeters;
  final String durationText;
  final int durationSeconds;

  DistanceResult({
    required this.distanceText,
    required this.distanceMeters,
    required this.durationText,
    required this.durationSeconds,
  });

  factory DistanceResult.unknown() => DistanceResult(
    distanceText: 'Unknown',
    distanceMeters: 0,
    durationText: 'Unknown',
    durationSeconds: 0,
  );

  @override
  String toString() => '$distanceText ($durationText)';
}
