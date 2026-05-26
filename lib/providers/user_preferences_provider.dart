import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesProvider extends ChangeNotifier {
  static const String _keyCustomGreetingName = 'pref_custom_greeting_name';
  static const String _keyThemeMode = 'pref_theme_mode';
  static const String _keyDietaryFilter = 'pref_dietary_filter';
  static const String _keyAddressLabel = 'pref_address_label';
  static const String _keyDeliveryInstructions = 'pref_delivery_instructions';

  String _customGreetingName = '';
  String _themeMode = 'orange';
  String _dietaryFilter = 'none';
  String _addressLabel = 'Home';
  String _deliveryInstructions = '';

  String get customGreetingName => _customGreetingName;
  String get themeMode => _themeMode;
  String get dietaryFilter => _dietaryFilter;
  String get addressLabel => _addressLabel;
  String get deliveryInstructions => _deliveryInstructions;

  UserPreferencesProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customGreetingName = prefs.getString(_keyCustomGreetingName) ?? '';
      _themeMode = prefs.getString(_keyThemeMode) ?? 'orange';
      _dietaryFilter = prefs.getString(_keyDietaryFilter) ?? 'none';
      _addressLabel = prefs.getString(_keyAddressLabel) ?? 'Home';
      _deliveryInstructions = prefs.getString(_keyDeliveryInstructions) ?? '';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> setCustomGreetingName(String name) async {
    _customGreetingName = name;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomGreetingName, name);
  }

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  Future<void> setDietaryFilter(String filter) async {
    _dietaryFilter = filter;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDietaryFilter, filter);
  }

  Future<void> setAddressLabel(String label) async {
    _addressLabel = label;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAddressLabel, label);
  }

  Future<void> setDeliveryInstructions(String instructions) async {
    _deliveryInstructions = instructions;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeliveryInstructions, instructions);
  }
}
