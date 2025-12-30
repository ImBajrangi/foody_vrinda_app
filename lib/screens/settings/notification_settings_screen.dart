import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../config/notification_sound_config.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Available notification sounds (including system default)
  final List<Map<String, String>> _availableSounds = [
    {'name': 'System Default', 'file': 'default'},
    {'name': 'Bell Notification', 'file': 'mixkit-bell-notification-933.wav'},
    {'name': 'Happy Bells', 'file': 'mixkit-happy-bells-notification-937.wav'},
    {'name': 'Magic Marimba', 'file': 'mixkit-magic-marimba-2820.wav'},
    {'name': 'Doorbell', 'file': 'mixkit-doorbell-single-press-333.wav'},
    {'name': 'Urgent Tone', 'file': 'mixkit-urgent-simple-tone-loop-2976.wav'},
    {'name': 'Elevator Tone', 'file': 'mixkit-elevator-tone-2863.wav'},
    {
      'name': 'Guitar Alert',
      'file': 'mixkit-guitar-notification-alert-2320.wav',
    },
    {'name': 'Magic Ring', 'file': 'mixkit-magic-notification-ring-2344.wav'},
    {'name': 'Clear Announce', 'file': 'mixkit-clear-announce-tones-2861.wav'},
    {
      'name': 'Pop Up',
      'file': 'mixkit-bubble-pop-up-alert-notification-2357.wav',
    },
    {'name': 'Sci-Fi Click', 'file': 'mixkit-sci-fi-click-900.wav'},
    {'name': 'Correct Answer', 'file': 'mixkit-correct-answer-reward-952.wav'},
  ];

  String? _selectedSound;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSound();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentSound = prefs.getString('notification_sound') ?? 'default';
      setState(() {
        _selectedSound = currentSound;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _selectedSound = 'default';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSound(String soundFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notification_sound', soundFile);

      // Also update role-specific sounds if needed
      await prefs.setString('sound_owner', soundFile);
      await prefs.setString('sound_kitchen', soundFile);
      await prefs.setString('sound_delivery', soundFile);

      // Reload the config cache
      await NotificationSoundConfig.reloadSounds();

      setState(() {
        _selectedSound = soundFile;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification sound updated'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving sound: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _previewSound(String soundFile) async {
    await _audioPlayer.stop();

    if (soundFile == 'default') {
      // For system default, just show a message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System default sound will be used'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    try {
      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not play sound: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('Notification Settings'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.notifications_active,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notification Sound',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Choose your preferred alert sound',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sound Selection
                const Text(
                  'SELECT SOUND',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                ..._availableSounds.map((sound) => _buildSoundTile(sound)),
              ],
            ),
    );
  }

  Widget _buildSoundTile(Map<String, String> sound) {
    final isSelected = _selectedSound == sound['file'];
    final isDefault = sound['file'] == 'default';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryBlue
              : AppTheme.border.withOpacity(0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => _saveSound(sound['file']!),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDefault
                ? AppTheme.textTertiary.withOpacity(0.1)
                : AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isDefault ? Icons.phone_android : Icons.music_note,
            color: isDefault ? AppTheme.textTertiary : AppTheme.primaryBlue,
            size: 20,
          ),
        ),
        title: Text(
          sound['name']!,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppTheme.primaryBlue : null,
          ),
        ),
        subtitle: isDefault
            ? const Text(
                'Uses your device\'s default notification sound',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDefault)
              IconButton(
                onPressed: () => _previewSound(sound['file']!),
                icon: const Icon(Icons.play_circle_outline, size: 24),
                color: AppTheme.primaryBlue,
                tooltip: 'Preview',
              ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primaryBlue),
          ],
        ),
      ),
    );
  }
}
