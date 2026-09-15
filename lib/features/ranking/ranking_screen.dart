import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/leaderboard_repository.dart';
import '../../shared/widgets/app_background.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({
    required this.user,
    required this.profile,
    required this.totalPoints,
    required this.leaderboardRepository,
    super.key,
  });

  final AuthUser user;
  final UserProfile profile;
  final int totalPoints;
  final LeaderboardRepository leaderboardRepository;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late Stream<List<LeaderboardEntry>> _topEntriesStream;
  Future<LeaderboardUserPosition?>? _positionFuture;
  String? _lastSyncKey;

  @override
  void initState() {
    super.initState();
    _topEntriesStream = widget.leaderboardRepository.watchTopEntries();
    _syncCurrentUserEntry();
  }

  @override
  void didUpdateWidget(covariant RankingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leaderboardRepository != widget.leaderboardRepository) {
      _topEntriesStream = widget.leaderboardRepository.watchTopEntries();
      _positionFuture = null;
      _lastSyncKey = null;
    }
    _syncCurrentUserEntry();
  }

  void _syncCurrentUserEntry() {
    final username = widget.profile.username?.trim();
    if (username == null || username.isEmpty) {
      return;
    }
    final syncKey = '${widget.user.uid}|$username|${widget.totalPoints}';
    if (_lastSyncKey == syncKey) {
      return;
    }
    _lastSyncKey = syncKey;
    unawaited(
      widget.leaderboardRepository.ensureEntryForCurrentUser(
        uid: widget.user.uid,
        username: username,
        totalPoints: widget.totalPoints,
      ),
    );
    _positionFuture = widget.leaderboardRepository.fetchUserPosition(
      uid: widget.user.uid,
      username: username,
      totalPoints: widget.totalPoints,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: AppBackground(
          child: StreamBuilder<List<LeaderboardEntry>>(
            stream: _topEntriesStream,
            builder: (context, snapshot) {
              final entries = snapshot.data ?? const <LeaderboardEntry>[];
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizing.maxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          AppStrings.rankingTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RankingCard(
                          entries: entries,
                          currentUserId: widget.user.uid,
                          isLoading:
                              snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData,
                          error: snapshot.error,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _CurrentUserPositionCard(
                          positionFuture: _positionFuture,
                          currentUserId: widget.user.uid,
                          topEntries: entries,
                          totalPoints: widget.totalPoints,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.entries,
    required this.currentUserId,
    required this.isLoading,
    required this.error,
  });

  final List<LeaderboardEntry> entries;
  final String currentUserId;
  final bool isLoading;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(
              icon: Icons.leaderboard_outlined,
              title: AppStrings.generalRankingTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            if (isLoading)
              const _LoadingState()
            else if (error != null)
              const _MessageState(
                icon: Icons.error_outline,
                title: AppStrings.rankingLoadError,
                body: AppStrings.retryLater,
              )
            else if (entries.isEmpty)
              const _MessageState(
                icon: Icons.emoji_events_outlined,
                title: AppStrings.emptyRankingTitle,
                body: AppStrings.emptyRankingBody,
              )
            else
              ..._rankedRows(),
          ],
        ),
      ),
    );
  }

  List<Widget> _rankedRows() {
    final rows = <Widget>[];
    var previousPoints = -1;
    var previousPosition = 0;
    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      final position = entry.totalPoints == previousPoints
          ? previousPosition
          : index + 1;
      previousPoints = entry.totalPoints;
      previousPosition = position;
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: AppSpacing.sm));
      }
      rows.add(
        _RankingRow(
          entry: entry,
          position: position,
          isCurrentUser: entry.userId == currentUserId,
        ),
      );
    }
    return rows;
  }
}

class _CurrentUserPositionCard extends StatelessWidget {
  const _CurrentUserPositionCard({
    required this.positionFuture,
    required this.currentUserId,
    required this.topEntries,
    required this.totalPoints,
  });

  final Future<LeaderboardUserPosition?>? positionFuture;
  final String currentUserId;
  final List<LeaderboardEntry> topEntries;
  final int totalPoints;

  @override
  Widget build(BuildContext context) {
    final topEntry = _topEntryForCurrentUser();
    final topPosition = topEntry == null ? null : _positionFor(topEntry);

    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(
              icon: Icons.person_pin_circle_outlined,
              title: AppStrings.yourRankingPositionTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            if (totalPoints <= 0)
              const _MessageState(
                icon: Icons.flag_outlined,
                title: AppStrings.noRankingPositionTitle,
                body: AppStrings.noRankingPositionBody,
              )
            else if (topEntry != null && topPosition != null)
              _RankingRow(
                entry: topEntry,
                position: topPosition,
                isCurrentUser: true,
                compact: true,
              )
            else
              FutureBuilder<LeaderboardUserPosition?>(
                future: positionFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _LoadingState();
                  }
                  final position = snapshot.data;
                  if (position == null) {
                    return const _MessageState(
                      icon: Icons.flag_outlined,
                      title: AppStrings.noRankingPositionTitle,
                      body: AppStrings.noRankingPositionBody,
                    );
                  }
                  return _RankingRow(
                    entry: position.entry,
                    position: position.position,
                    isCurrentUser: true,
                    compact: true,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  LeaderboardEntry? _topEntryForCurrentUser() {
    for (final entry in topEntries) {
      if (entry.userId == currentUserId) {
        return entry;
      }
    }
    return null;
  }

  int? _positionFor(LeaderboardEntry target) {
    var higherScores = 0;
    final seenScores = <int>{};
    for (final entry in topEntries) {
      if (entry.totalPoints > target.totalPoints) {
        seenScores.add(entry.totalPoints);
        higherScores += 1;
      }
    }
    return higherScores + 1;
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.entry,
    required this.position,
    required this.isCurrentUser,
    this.compact = false,
  });

  final LeaderboardEntry entry;
  final int position;
  final bool isCurrentUser;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final highlightColor = colors.orangeSoft.withValues(alpha: 0.45);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isCurrentUser ? highlightColor : colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(
          color: isCurrentUser ? colors.orangePrimary : colors.border,
          width: isCurrentUser ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
        child: Row(
          children: [
            _PositionBadge(position: position),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.username,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isCurrentUser)
                        Text(
                          AppStrings.currentUserBadge,
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.orangeDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _formatPointsLabel(entry.totalPoints),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
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

class _PositionBadge extends StatelessWidget {
  const _PositionBadge({required this.position});

  final int position;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isPodium = position <= 3;
    final icon = switch (position) {
      1 => Icons.emoji_events,
      2 => Icons.military_tech,
      3 => Icons.workspace_premium,
      _ => null,
    };

    return SizedBox(
      width: 52,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isPodium ? colors.orangeSoft : colors.surfaceStrong,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(
            color: isPodium ? colors.orangePrimary : colors.border,
          ),
        ),
        child: Center(
          child: icon == null
              ? Text(
                  '#$position',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Semantics(
                  label: '#$position',
                  child: Icon(icon, color: colors.orangeDark),
                ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, color: colors.orangeDark),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, color: colors.orangeDark),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          body,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

String _formatPointsLabel(int points) {
  final suffix = points == 1 ? 'punto' : 'puntos';
  return '${_formatPoints(points)} $suffix';
}

String _formatPoints(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index += 1) {
    final remaining = text.length - index;
    buffer.write(text[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}
