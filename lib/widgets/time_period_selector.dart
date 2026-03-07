import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../config/lottie_assets.dart';
import '../config/theme.dart';
import '../models/shop_model.dart';

/// Beautiful time period selector with Lottie animations
class TimePeriodSelector extends StatelessWidget {
  final Set<String> selectedPeriods;
  final ValueChanged<Set<String>> onChanged;
  final bool showHeader;

  const TimePeriodSelector({
    super.key,
    required this.selectedPeriods,
    required this.onChanged,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Lottie.network(
                  LottieAssets.clock,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.schedule, color: AppTheme.primaryBlue),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operating Hours',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Select when your shop is open',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        // Time Period Cards Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: TimePeriod.values.length,
          itemBuilder: (context, index) {
            final period = TimePeriod.values[index];
            final isSelected = selectedPeriods.contains(period.name);
            return _TimePeriodCard(
              period: period,
              isSelected: isSelected,
              onTap: () {
                final newSet = Set<String>.from(selectedPeriods);
                if (isSelected) {
                  newSet.remove(period.name);
                } else {
                  newSet.add(period.name);
                }
                onChanged(newSet);
              },
            );
          },
        ),
        const SizedBox(height: 12),
        // Quick select buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  onChanged(TimePeriod.values.map((p) => p.name).toSet());
                },
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('Select All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.success,
                  side: const BorderSide(color: AppTheme.success),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onChanged({}),
                icon: const Icon(Icons.deselect, size: 16),
                label: const Text('Clear All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.borderLight),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimePeriodCard extends StatelessWidget {
  final TimePeriod period;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimePeriodCard({
    required this.period,
    required this.isSelected,
    required this.onTap,
  });

  /// Get gradient colors based on time period
  List<Color> get _gradientColors {
    switch (period) {
      case TimePeriod.morning:
        return [const Color(0xFFFFAD47), const Color(0xFFFF7B42)];
      case TimePeriod.forenoon:
        return [const Color(0xFFFFD93D), const Color(0xFFFF9A3D)];
      case TimePeriod.afternoon:
        return [const Color(0xFF5AC8FA), const Color(0xFF007AFF)];
      case TimePeriod.evening:
        return [const Color(0xFFAF52DE), const Color(0xFF5856D6)];
      case TimePeriod.night:
        return [const Color(0xFF5856D6), const Color(0xFF1C1C3E)];
    }
  }

  /// Get Lottie animation URL based on time period
  String get _lottieUrl {
    switch (period) {
      case TimePeriod.morning:
        return LottieAssets.sunrise;
      case TimePeriod.forenoon:
        return LottieAssets.sun;
      case TimePeriod.afternoon:
        return LottieAssets.sun;
      case TimePeriod.evening:
        return LottieAssets.sunset;
      case TimePeriod.night:
        return LottieAssets.moon;
    }
  }

  /// Get icon fallback
  IconData get _fallbackIcon {
    switch (period) {
      case TimePeriod.morning:
        return Icons.wb_twilight;
      case TimePeriod.forenoon:
        return Icons.wb_sunny;
      case TimePeriod.afternoon:
        return Icons.lunch_dining;
      case TimePeriod.evening:
        return Icons.nightlight_round;
      case TimePeriod.night:
        return Icons.bedtime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSelected
              ? _gradientColors
              : [AppTheme.cardBackground, AppTheme.cardBackground],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.3)
              : AppTheme.borderLight,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: _gradientColors.first.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Lottie animation in background
              Positioned(
                top: 4,
                right: 4,
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: Lottie.network(
                    _lottieUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      _fallbackIcon,
                      size: 36,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppTheme.textSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${period.emoji} ${period.displayName}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      period.timeRange,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Checkmark
              if (isSelected)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: _gradientColors.first,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact version for display-only purposes
class TimePeriodDisplay extends StatelessWidget {
  final List<String> timePeriods;

  const TimePeriodDisplay({super.key, required this.timePeriods});

  @override
  Widget build(BuildContext context) {
    if (timePeriods.isEmpty) {
      return const Text(
        'Always Open',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: timePeriods.map((periodName) {
        final period = TimePeriod.values.firstWhere(
          (p) => p.name == periodName,
          orElse: () => TimePeriod.morning,
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${period.emoji} ${period.displayName}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryBlue,
            ),
          ),
        );
      }).toList(),
    );
  }
}
