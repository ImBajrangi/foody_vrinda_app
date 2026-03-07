import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

/// Service for Google Maps APIs (Places, Distance Matrix, Geocoding)
class LocationService {
  // Use the same API key from AndroidManifest
  static const String _apiKey = 'AIzaSyDWEKXSvzY2bMStntZKoGmGh0W6Pa7YUXM';

  /// Get place predictions for address autocomplete (Using Nominatim for free)
  static Future<List<PlacePrediction>> getPlacePredictions(String input) async {
    if (input.isEmpty) return [];

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(input)}'
      '&format=json'
      '&addressdetails=1'
      '&limit=5'
      '&countrycodes=in', // Restrict to India
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'foody_vrinda_app'},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((p) => PlacePrediction.fromNominatim(p)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting place predictions: $e');
      return [];
    }
  }

  /// Get place details (lat/lng) from place ID (Using cached data or Nominatim)
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    // For Nominatim, the placeId we returned in predictions is actually "lat,lng" for simplicity
    // or we can re-query. In our simplified implementation below, placeId is coordinates.
    try {
      final parts = placeId.split(',');
      if (parts.length == 2) {
        final lat = double.parse(parts[0]);
        final lng = double.parse(parts[1]);
        return PlaceDetails(
          location: LatLng(lat, lng),
          formattedAddress: '', // Nominatim returns full address in search
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting place details: $e');
      return null;
    }
  }

  /// Geocode an address to get lat/lng (Free version using platform native geocoding)
  static Future<LatLng?> geocodeAddress(String address) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        0,
        0,
      ); // This is just a placeholder, wait
      // Use the geocoding package
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
      return null;
    } catch (e) {
      debugPrint('Error geocoding address natively: $e');
      // Fallback to Google if native fails (optional, but let's try to be purely free first as requested)
      return _googleGeocodeAddress(address);
    }
  }

  /// Original Google implementation as fallback
  static Future<LatLng?> _googleGeocodeAddress(String address) async {
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
      debugPrint('Error geocoding address via Google: $e');
      return null;
    }
  }

  /// Calculate distance and duration between two points (Using OSRM for free)
  static Future<DistanceResult?> getDistanceMatrix({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
      '?overview=false',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final distanceMeters = (route['distance'] as num).toInt();
          final durationSeconds = (route['duration'] as num).toInt();

          return DistanceResult(
            distanceText: '${(distanceMeters / 1000).toStringAsFixed(1)} km',
            distanceMeters: distanceMeters,
            durationText: '${(durationSeconds / 60).round()} mins',
            durationSeconds: durationSeconds,
          );
        }
      }
      // Fallback to straight line calculation if OSRM fails
      return _calculateStraightLineDistance(origin, destination);
    } catch (e) {
      debugPrint('Error getting OSRM distance: $e');
      return _calculateStraightLineDistance(origin, destination);
    }
  }

  static DistanceResult _calculateStraightLineDistance(LatLng o, LatLng d) {
    const Distance distance = Distance();
    final double meter = distance.as(LengthUnit.Meter, o, d);
    return DistanceResult(
      distanceText: '${(meter / 1000).toStringAsFixed(1)} km',
      distanceMeters: meter.toInt(),
      durationText: '${(meter / 500).round()} mins', // Rough estimate 30km/h
      durationSeconds: (meter / 8).round(),
    );
  }

  /// Calculate distances from one origin to multiple destinations
  static Future<List<DistanceResult>> getMultipleDistances({
    required LatLng origin,
    required List<LatLng> destinations,
  }) async {
    if (destinations.isEmpty) return [];

    final destinationsStr = destinations
        .map((d) => '${d.latitude},${d.longitude}')
        .join('|');

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
      '?origins=${origin.latitude},${origin.longitude}'
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

  factory PlacePrediction.fromNominatim(Map<String, dynamic> json) {
    final displayName = json['display_name'] ?? '';
    final address = json['address'] ?? {};

    // Extract main text (e.g., place name or street)
    String main =
        address['name'] ??
        address['road'] ??
        address['suburb'] ??
        address['city'] ??
        'Unknown';

    return PlacePrediction(
      placeId: '${json['lat']},${json['lon']}',
      description: displayName,
      mainText: main,
      secondaryText: displayName.startsWith(main)
          ? displayName
                .substring(main.length)
                .trim()
                .replaceFirst(',', '')
                .trim()
          : displayName,
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
