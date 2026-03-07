import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Singleton service that manages persistent alarm for new delivery orders.
/// Plays a looping sound when new orders are ready for delivery and not acknowledged.
class DeliveryAlarmService extends ChangeNotifier {
  static final DeliveryAlarmService _instance = DeliveryAlarmService._internal();
  factory DeliveryAlarmService() => _instance;
  DeliveryAlarmService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<String> _unacknowledgedOrders = {};
  bool _isPlaying = false;

  /// Returns true if alarm is currently active
  bool get isAlarmActive => _unacknowledgedOrders.isNotEmpty;

  /// Returns count of unacknowledged orders
  int get unacknowledgedCount => _unacknowledgedOrders.length;

  /// Trigger alarm for a new order ready for delivery
  Future<void> triggerAlarm(String orderId) async {
    if (_unacknowledgedOrders.contains(orderId)) return;

    _unacknowledgedOrders.add(orderId);
    notifyListeners();

    if (!_isPlaying) {
      await _startAlarmSound();
    }
  }

  /// Acknowledge all orders and stop the alarm
  Future<void> acknowledgeAll() async {
    _unacknowledgedOrders.clear();
    await _stopAlarmSound();
    notifyListeners();
  }

  /// Acknowledge a specific order
  Future<void> acknowledgeOrder(String orderId) async {
    _unacknowledgedOrders.remove(orderId);
    if (_unacknowledgedOrders.isEmpty) {
      await _stopAlarmSound();
    }
    notifyListeners();
  }

  Future<void> _startAlarmSound() async {
    if (_isPlaying) return;
    
    try {
      _isPlaying = true;
      // Use a different sound for delivery - motorcycle horn style
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(
        AssetSource('sounds/mixkit-urgent-simple-tone-loop-2976.wav'),
      );
    } catch (e) {
      debugPrint('DeliveryAlarmService: Error playing alarm: $e');
      _isPlaying = false;
    }
  }

  Future<void> _stopAlarmSound() async {
    if (!_isPlaying) return;
    
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('DeliveryAlarmService: Error stopping alarm: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
