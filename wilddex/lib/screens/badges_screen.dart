import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_data.dart';
import '../models/badge.dart';
import '../theme/colors.dart';
import '../utils/badge_engine.dart';
import '../utils/user_data_provider.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badges'),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.foreground,
      ),
      body: FutureBuilder<List<BadgeDefinition>>(
        future: BadgeEngine.loadDefinitions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final defs = snapshot.data ?? [];
          return Consumer<UserDataProvider>(
            builder: (context, userData, _) {
              final summary = BadgeEngine.evaluate(defs, appData, userData);
              final sorted = _sortBadges(summary.badges);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _BadgeSummaryHeader(summary: summary),
                  const SizedBox(height: 16),
                  ...sorted.map((status) => _BadgeCard(status: status)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<BadgeStatus> _sortBadges(List<BadgeStatus> badges) {
    final tierOrder = {
      'common': 0,
      'uncommon': 1,
      'rare': 2,
      'epic': 3,
      'legendary': 4,
      'mythic': 5,
    };
    badges.sort((a, b) {
      final tierA = tierOrder[a.definition.tier.toLowerCase()] ?? 99;
      final tierB = tierOrder[b.definition.tier.toLowerCase()] ?? 99;
      if (tierA != tierB) return tierA.compareTo(tierB);
      final targetA = a.target;
      final targetB = b.target;
      if (targetA != targetB) return targetA.compareTo(targetB);
      return a.definition.name.compareTo(b.definition.name);
    });
    return badges;
  }
}

class _BadgeSummaryHeader extends StatelessWidget {
  final BadgeSummary summary;
  const _BadgeSummaryHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    final earned = summary.badges.where((b) => b.isEarned).length;
    final total = summary.badges.length;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.levelName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${summary.totalPoints} points',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$earned / $total',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text('badges'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeStatus status;
  const _BadgeCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final tierColor = status.isComplete
        ? _tierColor(status.definition.tier)
        : AppColors.tierLocked;
    final target = status.target;
    final showProgress = target > 1;
    final progressText = target > 0 ? '${status.current} / $target' : '';
    final earnedAt = status.earnedAt;
    final earnedText = earnedAt != null
        ? '${earnedAt.month}/${earnedAt.day}/${earnedAt.year}'
        : null;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tierColor.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: tierColor, width: 2),
                  ),
                  child: Icon(
                    status.isComplete ? Icons.emoji_events : Icons.lock_outline,
                    color: tierColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.definition.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status.definition.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (earnedText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Earned $earnedText',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: tierColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _TierPill(
                  label: status.definition.tier,
                  color: tierColor,
                ),
              ],
            ),
            if (status.isEarned) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: _EarnedPill(color: tierColor),
              ),
            ],
            if (showProgress) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: status.progress,
                backgroundColor: AppColors.shadow,
                valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                minHeight: 6,
              ),
              const SizedBox(height: 6),
              Text(
                progressText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'common':
        return AppColors.tierCommon;
      case 'uncommon':
        return AppColors.tierUncommon;
      case 'rare':
        return AppColors.tierRare;
      case 'epic':
        return AppColors.tierEpic;
      case 'legendary':
        return AppColors.tierLegendary;
      case 'mythic':
        return AppColors.tierMythic;
      default:
        return AppColors.text;
    }
  }
}

class _TierPill extends StatelessWidget {
  final String label;
  final Color color;
  const _TierPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _EarnedPill extends StatelessWidget {
  final Color color;
  const _EarnedPill({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        'EARNED',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
