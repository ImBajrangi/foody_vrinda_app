import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/location_service.dart';
import 'package:latlong2/latlong.dart';

/// A text field with address autocomplete powered by Google Places API
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final Function(String address, LatLng? location)? onAddressSelected;
  final InputDecoration? decoration;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.onAddressSelected,
    this.decoration,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<PlacePrediction> _predictions = [];
  Timer? _debounce;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(widget.controller.text);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      _removeOverlay();
      setState(() => _predictions = []);
      return;
    }

    setState(() => _isLoading = true);

    final predictions = await LocationService.getPlacePredictions(query);

    if (mounted) {
      setState(() {
        _predictions = predictions;
        _isLoading = false;
      });

      if (predictions.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 48,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.cardBackground,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _predictions.map((prediction) {
                      return InkWell(
                        onTap: () => _selectPlace(prediction),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppTheme.borderLight.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: AppTheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      prediction.mainText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (prediction.secondaryText.isNotEmpty)
                                      Text(
                                        prediction.secondaryText,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    _removeOverlay();
    widget.controller.text = prediction.description;
    setState(() => _predictions = []);

    // Get the coordinates for this place
    final details = await LocationService.getPlaceDetails(prediction.placeId);

    widget.onAddressSelected?.call(prediction.description, details?.location);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        decoration:
            widget.decoration ??
            InputDecoration(
              hintText: widget.hintText ?? 'Enter delivery address',
              labelText: widget.labelText,
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        widget.controller.clear();
                        _removeOverlay();
                        setState(() => _predictions = []);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primaryBlue,
                  width: 2,
                ),
              ),
            ),
        onTap: () {
          if (_predictions.isNotEmpty) {
            _showOverlay();
          }
        },
      ),
    );
  }
}
