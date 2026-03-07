import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';

/// Screen for configuring notification sounds for different user roles
class NotificationSoundSettings extends StatefulWidget {
  const NotificationSoundSettings({super.key});

  @override
  State<NotificationSoundSettings> createState() =>
      _NotificationSoundSettingsState();
}

class _NotificationSoundSettingsState extends State<NotificationSoundSettings> {
  // Available sound files in assets/sounds/
  final List<String> availableSounds = [
    'mixkit-access-allowed-tone-2869.wav',
    'mixkit-arabian-mystery-harp-notification-2489.wav',
    'mixkit-atm-cash-machine-key-press-2841.wav',
    'mixkit-bell-notification-933.wav',
    'mixkit-bubble-pop-up-alert-notification-2357.wav',
    'mixkit-chewing-something-crunchy-2244.wav',
    'mixkit-clear-announce-tones-2861.wav',
    'mixkit-correct-answer-reward-952.wav',
    'mixkit-doorbell-single-press-333.wav',
    'mixkit-dry-pop-up-notification-alert-2356.wav',
    'mixkit-elevator-tone-2863.wav',
    'mixkit-guitar-notification-alert-2320.wav',
    'mixkit-happy-bells-notification-937.wav',
    'mixkit-interface-option-select-2573.wav',
    'mixkit-magic-marimba-2820.wav',
    'mixkit-magic-notification-ring-2344.wav',
    'mixkit-melodical-flute-music-notification-2310.wav',
    'mixkit-placing-cutlery-on-a-plate-132.wav',
    'mixkit-pouring-foamy-soda-3181.wav',
    'mixkit-sci-fi-click-900.wav',
    'mixkit-sci-fi-confirmation-914.wav',
    'mixkit-software-interface-remove-2576.wav',
    'mixkit-urgent-simple-tone-loop-2976.wav',
    'mixkit-wrong-answer-fail-notification-946.wav',
  ];

  // Current sound selections
  Map<String, String> selectedSounds = {
    'owner': 'mixkit-bell-notification-933.wav',
    'kitchen': 'mixkit-urgent-simple-tone-loop-2976.wav',
    'delivery': 'mixkit-doorbell-single-press-333.wav',
  };

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedSounds();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Load saved sound preferences
  Future<void> _loadSavedSounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        selectedSounds['owner'] =
            prefs.getString('sound_owner') ??
            'mixkit-bell-notification-933.wav';
        selectedSounds['kitchen'] =
            prefs.getString('sound_kitchen') ??
            'mixkit-urgent-simple-tone-loop-2976.wav';
        selectedSounds['delivery'] =
            prefs.getString('sound_delivery') ??
            'mixkit-doorbell-single-press-333.wav';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sound preferences: $e')),
        );
      }
    }
  }

  /// Save sound preferences
  Future<void> _saveSoundPreference(String role, String soundFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sound_$role', soundFile);
      setState(() {
        selectedSounds[role] = soundFile;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sound saved for ${_getRoleName(role)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving sound: $e')));
      }
    }
  }

  /// Preview a sound
  Future<void> _playSound(String soundFile) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing sound: $e')));
      }
    }
  }

  /// Get human-readable role name
  String _getRoleName(String role) {
    switch (role) {
      case 'owner':
        return 'Shop Owner';
      case 'kitchen':
        return 'Kitchen Staff';
      case 'delivery':
        return 'Delivery Staff';
      default:
        return role;
    }
  }

  /// Get friendly name for sound file
  String _getSoundName(String fileName) {
    return fileName
        .replaceAll('mixkit-', '')
        .replaceAll('.wav', '')
        .replaceAll('-', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  /// Show sound picker dialog
  void _showSoundPicker(String role) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderColor, width: 1),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.1),
                      AppTheme.primaryBlue.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getRoleIcon(role),
                      color: AppTheme.primaryGreen,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose Sound',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            _getRoleName(role),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
              // Sound list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: availableSounds.length,
                  itemBuilder: (context, index) {
                    final sound = availableSounds[index];
                    final isSelected = selectedSounds[role] == sound;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : AppTheme.borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isSelected
                                  ? [
                                      AppTheme.primaryGreen,
                                      AppTheme.primaryBlue,
                                    ]
                                  : [
                                      Colors.grey.shade700,
                                      Colors.grey.shade800,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isSelected ? Icons.check_circle : Icons.music_note,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          _getSoundName(sound),
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          sound,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.play_circle_filled,
                            color: AppTheme.primaryGreen,
                            size: 28,
                          ),
                          onPressed: () => _playSound(sound),
                        ),
                        onTap: () {
                          _saveSoundPreference(role, sound);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get icon for role
  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'owner':
        return Icons.store;
      case 'kitchen':
        return Icons.restaurant;
      case 'delivery':
        return Icons.delivery_dining;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Notification Sounds'),
          backgroundColor: AppTheme.cardBackground,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notification Sound Settings'),
        backgroundColor: AppTheme.cardBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.cardBackground,
                  title: Text(
                    'About Notification Sounds',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  content: Text(
                    'Configure different notification sounds for each staff role. '
                    'Tap on a role card to select a sound, and use the play button to preview it.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGreen.withValues(alpha: 0.1),
                    AppTheme.primaryBlue.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.music_note,
                    size: 40,
                    color: AppTheme.primaryGreen,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notification Sound Configuration',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Customize notification sounds for different staff roles',
                          style: TextStyle(
                            fontSize: 14,
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

            // Role sound cards
            _buildRoleCard('owner'),
            const SizedBox(height: 16),
            _buildRoleCard('kitchen'),
            const SizedBox(height: 16),
            _buildRoleCard('delivery'),

            const SizedBox(height: 24),

            // Test notification button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Test current sounds
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.cardBackground,
                      title: Text(
                        'Test Sounds',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTestButton('owner'),
                          const SizedBox(height: 8),
                          _buildTestButton('kitchen'),
                          const SizedBox(height: 8),
                          _buildTestButton('delivery'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Test All Sounds'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(String role) {
    final sound = selectedSounds[role]!;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSoundPicker(role),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Role icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryGreen, AppTheme.primaryBlue],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getRoleIcon(role),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                // Role info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getRoleName(role),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getSoundName(sound),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        sound,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Play and edit buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.play_circle_filled,
                        color: AppTheme.primaryGreen,
                        size: 32,
                      ),
                      onPressed: () => _playSound(sound),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestButton(String role) {
    return ElevatedButton(
      onPressed: () => _playSound(selectedSounds[role]!),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
        foregroundColor: AppTheme.textPrimary,
        minimumSize: const Size(double.infinity, 50),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getRoleIcon(role)),
          const SizedBox(width: 12),
          Text(_getRoleName(role)),
        ],
      ),
    );
  }
}
