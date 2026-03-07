import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../config/theme.dart';

/// Uber-style location picker with a center pin marker
/// The marker stays fixed in center while the map moves beneath it
class LocationPickerDialog extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerDialog({super.key, this.initialLocation});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final MapController _mapController = MapController();
  LatLng _centerLocation = const LatLng(28.6139, 77.2090); // Default Delhi
  String _addressDisplay = 'Move the map to select location';
  bool _isLoading = true;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _centerLocation = widget.initialLocation!;
    }
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      // If initial location provided, use it
      if (widget.initialLocation != null) {
        _centerLocation = widget.initialLocation!;
        setState(() => _isLoading = false);
        _updateAddressFromLatLng(_centerLocation);
        return;
      }

      // Check location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }

      // Get current position with reduced accuracy for faster load
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // Faster initial load
          timeLimit: Duration(seconds: 5),
        ),
      );

      _centerLocation = LatLng(position.latitude, position.longitude);
      setState(() => _isLoading = false);
      _updateAddressFromLatLng(_centerLocation);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// Reverse geocode to get address from coordinates
  Future<void> _updateAddressFromLatLng(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final address = [
          place.street,
          place.subLocality,
          place.locality,
          place.postalCode,
        ].where((s) => s != null && s.isNotEmpty).join(', ');

        setState(() {
          _addressDisplay = address.isNotEmpty ? address : 'Location selected';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addressDisplay =
              '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
        });
      }
    }
  }

  /// Called when map camera starts moving
  void _onCameraMoveStarted() {
    if (!_isMoving) {
      setState(() => _isMoving = true);
    }
  }

  /// Called when map camera stops (user releases drag)
  void _onCameraIdle() {
    if (_isMoving) {
      setState(() => _isMoving = false);
      _updateAddressFromLatLng(_centerLocation);
    }
  }

  /// Animate map to user's current location
  Future<void> _goToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final newLocation = LatLng(position.latitude, position.longitude);
      _mapController.move(newLocation, 16);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              // Premium Header
              _buildHeader(),

              // Map with center pin
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : Stack(
                        children: [
                          // OpenStreetMap using flutter_map
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _centerLocation,
                              initialZoom: 16,
                              onPositionChanged: (position, hasGesture) {
                                if (hasGesture) {
                                  _centerLocation = position.center;
                                }
                              },
                              onMapEvent: (event) {
                                if (event is MapEventMoveStart) {
                                  _onCameraMoveStarted();
                                } else if (event is MapEventMoveEnd) {
                                  _onCameraIdle();
                                }
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                subdomains: const ['a', 'b', 'c', 'd'],
                                userAgentPackageName: 'com.foody.vrinda.app',
                              ),
                            ],
                          ),

                          // Fixed Center Pin (Uber-style)
                          Center(child: _buildCenterPin()),

                          // Current Location FAB
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: _buildLocationFAB(),
                          ),

                          // Address Overlay at top
                          Positioned(
                            top: 12,
                            left: 12,
                            right: 12,
                            child: _buildAddressCard(),
                          ),
                        ],
                      ),
              ),

              // Footer with Confirm Button
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryOrange, Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick Location',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Drag map to move the pin',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: AppTheme.textSecondary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.primaryOrange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Getting your location...',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Uber-style center pin with shadow and bounce effect
  Widget _buildCenterPin() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pin with shadow
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          tween: Tween<double>(begin: 0, end: _isMoving ? -12 : 0),
          curve: Curves.easeOutBack,
          builder: (context, translateY, child) {
            return Transform.translate(
              offset: Offset(0, translateY),
              child: child,
            );
          },
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.primaryOrange, Color(0xFFFF8C00)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.4),
                  blurRadius: _isMoving ? 16 : 8,
                  spreadRadius: _isMoving ? 3 : 1,
                  offset: Offset(0, _isMoving ? 10 : 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        // Shadow dot on ground
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _isMoving ? 14 : 10,
          height: _isMoving ? 4 : 5,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: _isMoving ? 0.1 : 0.2),
            boxShadow: [
              if (!_isMoving)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 2,
                ),
            ],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationFAB() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _goToCurrentLocation,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: AppTheme.primaryBlue,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pin_drop_rounded,
                  color: AppTheme.primaryOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected Location',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isMoving ? 'Selecting...' : _addressDisplay,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _isMoving
                            ? AppTheme.textTertiary
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: AppTheme.border),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _centerLocation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Confirm Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
