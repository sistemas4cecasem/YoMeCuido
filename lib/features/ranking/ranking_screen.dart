import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/leaderboard_repository.dart';

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
  static const _rankingLimit = 10;

  late Stream<List<LeaderboardEntry>> _topEntriesStream;
  Future<LeaderboardUserPosition?>? _positionFuture;
  String? _lastPositionKey;
  List<LeaderboardEntry> _lastTopEntries = const <LeaderboardEntry>[];

  @override
  void initState() {
    super.initState();
    _topEntriesStream = widget.leaderboardRepository.watchTopEntries(
      limit: _rankingLimit,
    );
    _refreshCurrentUserPosition();
  }

  @override
  void didUpdateWidget(covariant RankingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leaderboardRepository != widget.leaderboardRepository) {
      _topEntriesStream = widget.leaderboardRepository.watchTopEntries(
        limit: _rankingLimit,
      );
      _positionFuture = null;
      _lastPositionKey = null;
      _lastTopEntries = const <LeaderboardEntry>[];
    }
    _refreshCurrentUserPosition();
  }

  void _refreshCurrentUserPosition() {
    final username = widget.profile.username?.trim();
    if (username == null || username.isEmpty) {
      return;
    }
    final positionKey = '${widget.user.uid}|$username|${widget.totalPoints}';
    if (_lastPositionKey == positionKey) {
      return;
    }
    _lastPositionKey = positionKey;
    _positionFuture = widget.leaderboardRepository.fetchUserPosition(
      uid: widget.user.uid,
      username: username,
      totalPoints: widget.totalPoints,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<LeaderboardEntry>>(
        stream: _topEntriesStream,
        builder: (context, snapshot) {
          final snapshotEntries = snapshot.data;
          if (snapshotEntries != null) {
            _lastTopEntries = snapshotEntries;
          }
          final entries = (snapshotEntries ?? _lastTopEntries)
              .take(_rankingLimit)
              .toList(growable: false);
          final showLoadError = snapshot.hasError && entries.isEmpty;
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData;
          final currentUserIsInTop = entries.any(
            (entry) => entry.userId == widget.user.uid,
          );
          final showCurrentUserPosition =
              !isLoading && (widget.totalPoints <= 0 || !currentUserIsInTop);
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
                      isLoading: isLoading,
                      error: showLoadError ? snapshot.error : null,
                    ),
                    if (showCurrentUserPosition) ...[
                      const SizedBox(height: AppSpacing.md),
                      _CurrentUserPositionCard(
                        positionFuture: _positionFuture,
                        totalPoints: widget.totalPoints,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
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
    final rankedEntries = _rankedEntries(entries);
    for (var index = 0; index < rankedEntries.length; index += 1) {
      final rankedEntry = rankedEntries[index];
      if (rows.isNotEmpty) {
        rows.add(_RankingDivider());
      }
      rows.add(
        _RankingRow(
          entry: rankedEntry.entry,
          position: rankedEntry.position,
          isCurrentUser: rankedEntry.entry.userId == currentUserId,
          highlight: rankedEntry.entry.userId == currentUserId,
        ),
      );
    }
    return rows;
  }
}

class _CurrentUserPositionCard extends StatelessWidget {
  const _CurrentUserPositionCard({
    required this.positionFuture,
    required this.totalPoints,
  });

  final Future<LeaderboardUserPosition?>? positionFuture;
  final int totalPoints;

  @override
  Widget build(BuildContext context) {
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
                    highlight: true,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.entry,
    required this.position,
    required this.isCurrentUser,
    this.highlight = false,
  });

  final LeaderboardEntry entry;
  final int position;
  final bool isCurrentUser;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label:
          'Puesto $position, ${entry.username}, ${_formatPointsLabel(entry.totalPoints)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: highlight ? colors.orangeSoft.withValues(alpha: 0.62) : null,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: highlight
              ? Border.all(color: colors.orangePrimary, width: 1.2)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              _PositionBadge(position: position),
              const SizedBox(width: AppSpacing.sm),
              _UserAvatar(isCurrentUser: isCurrentUser),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      entry.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _formatPointsLabel(entry.totalPoints),
                textAlign: TextAlign.end,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
    final badgeColor = switch (position) {
      1 => colors.orangePrimary,
      2 => colors.disabledText.withValues(alpha: 0.45),
      3 => colors.orangeDark.withValues(alpha: 0.82),
      _ => Colors.transparent,
    };
    final textColor = position <= 3
        ? colors.surfaceStrong
        : colors.textSecondary;

    return SizedBox(
      width: 38,
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
        child: Center(
          child: Text(
            '$position',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.isCurrentUser});

  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: 42,
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.orangeSoft.withValues(
            alpha: isCurrentUser ? 0.92 : 0.7,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person_outline, color: colors.orangeDark, size: 24),
      ),
    );
  }
}

class _RankingDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(left: 88),
      child: Divider(
        height: AppSpacing.sm,
        thickness: 1,
        color: colors.border.withValues(alpha: 0.72),
      ),
    );
  }
}

class _RankedEntry {
  const _RankedEntry({required this.entry, required this.position});

  final LeaderboardEntry entry;
  final int position;
}

List<_RankedEntry> _rankedEntries(List<LeaderboardEntry> entries) {
  final rankedEntries = <_RankedEntry>[];
  var previousPoints = -1;
  var previousPosition = 0;
  for (var index = 0; index < entries.length; index += 1) {
    final entry = entries[index];
    final position = entry.totalPoints == previousPoints
        ? previousPosition
        : index + 1;
    previousPoints = entry.totalPoints;
    previousPosition = position;
    rankedEntries.add(_RankedEntry(entry: entry, position: position));
  }
  return rankedEntries;
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
