import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../config/theme.dart';

class LocationPickerDialog extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerDialog({super.key, this.initialLocation});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  LatLng? _selectedLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      if (_selectedLocation == null) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          setState(() {
            _selectedLocation = const LatLng(
              28.6139,
              77.2090,
            ); // Default to Delhi
            _isLoading = false;
          });
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            setState(() {
              _selectedLocation = const LatLng(28.6139, 77.2090);
              _isLoading = false;
            });
            return;
          }
        }

        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _selectedLocation = const LatLng(28.6139, 77.2090);
        _isLoading = false;
      });
    }
  }

  void _onTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pick Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Map
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _selectedLocation!,
                            zoom: 15,
                          ),
                          onTap: _onTap,
                          markers: _selectedLocation == null
                              ? {}
                              : {
                                  Marker(
                                    markerId: const MarkerId('selected'),
                                    position: _selectedLocation!,
                                    icon: BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueAzure,
                                    ),
                                  ),
                                },
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                        ),

                        // Overlay Hint
                        PositionBag(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  size: 18,
                                  color: AppTheme.primaryBlue,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Tap on map to select shop location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedLocation != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppTheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                              'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedLocation == null
                              ? null
                              : () => Navigator.pop(context, _selectedLocation),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                          ),
                          child: const Text('Confirm'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple Positioned helper if needed, but standard Positioned is fine.
// I'll just use a Stack + Positioned in the code above.
// Wait, I used PositionBag above as a typo or placeholder. Let me fix it.
class PositionBag extends StatelessWidget {
  final double? top, bottom, left, right;
  final Widget child;
  const PositionBag({
    super.key,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Positioned(
    top: top,
    bottom: bottom,
    left: left,
    right: right,
    child: child,
  );
}
