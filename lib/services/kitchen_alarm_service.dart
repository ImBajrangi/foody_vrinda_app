import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service for managing persistent kitchen alarm for new orders
/// Rings continuously until all orders are acknowledged
class KitchenAlarmService extends ChangeNotifier {
  static final KitchenAlarmService _instance = KitchenAlarmService._internal();
  factory KitchenAlarmService() => _instance;
  KitchenAlarmService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<String> _unacknowledgedOrderIds = {};
  bool _isPlaying = false;

  // Alarm sound file - using the looping urgent tone
  static const String _alarmSoundFile = 'sounds/mixkit-urgent-simple-tone-loop-2976.wav';

  /// Get unacknowledged order IDs
  Set<String> get unacknowledgedOrders => Set.unmodifiable(_unacknowledgedOrderIds);

  /// Check if alarm is currently active
  bool get isAlarmActive => _isPlaying && _unacknowledgedOrderIds.isNotEmpty;

  /// Number of unacknowledged orders
  int get unacknowledgedCount => _unacknowledgedOrderIds.length;

  /// Initialize the alarm service
  Future<void> initialize() async {
    // Set player to loop mode
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    
    // Listen for player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        // If we still have unacknowledged orders, restart
        if (_unacknowledgedOrderIds.isNotEmpty && _isPlaying) {
          _playAlarm();
        }
      }
    });

    print('KitchenAlarmService: Initialized');
  }

  /// Trigger alarm for a new order
  Future<void> triggerAlarm(String orderId) async {
    print('KitchenAlarmService: Triggering alarm for order $orderId');
    
    // Add to unacknowledged list
    _unacknowledgedOrderIds.add(orderId);
    
    // Start playing if not already
    if (!_isPlaying) {
      await _playAlarm();
    }
    
    notifyListeners();
  }

  /// Play the alarm sound
  Future<void> _playAlarm() async {
    try {
      _isPlaying = true;
      await _audioPlayer.play(AssetSource(_alarmSoundFile));
      print('KitchenAlarmService: Alarm started');
    } catch (e) {
      print('KitchenAlarmService: Error playing alarm: $e');
      _isPlaying = false;
    }
  }

  /// Acknowledge a specific order
  Future<void> acknowledgeOrder(String orderId) async {
    print('KitchenAlarmService: Acknowledging order $orderId');
    
    _unacknowledgedOrderIds.remove(orderId);
    
    // Stop alarm if no more unacknowledged orders
    if (_unacknowledgedOrderIds.isEmpty) {
      await _stopAlarm();
    }
    
    notifyListeners();
  }

  /// Acknowledge all orders and stop alarm
  Future<void> acknowledgeAll() async {
    print('KitchenAlarmService: Acknowledging all orders');
    
    _unacknowledgedOrderIds.clear();
    await _stopAlarm();
    
    notifyListeners();
  }

  /// Stop the alarm
  Future<void> _stopAlarm() async {
    try {
      _isPlaying = false;
      await _audioPlayer.stop();
      print('KitchenAlarmService: Alarm stopped');
    } catch (e) {
      print('KitchenAlarmService: Error stopping alarm: $e');
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
