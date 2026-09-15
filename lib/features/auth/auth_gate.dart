import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../shared/widgets/primary_button.dart';
import '../main/main_authenticated_shell.dart';
import 'complete_profile_screen.dart';
import 'email_verification_screen.dart';
import '../splash/welcome_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.authRepository,
    required this.userProfileRepository,
    required this.progressController,
    required this.contentRepository,
    super.key,
  });

  final AuthRepository authRepository;
  final UserProfileRepository userProfileRepository;
  final CategoryProgressController progressController;
  final ContentRepository contentRepository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<AuthUser?> _authChanges;
  String? _lastUserUid;
  AuthUser? _checkedUser;
  String? _profileLoadUid;
  Future<UserProfile?>? _profileLoadFuture;
  String? _progressLoadUid;
  Future<void>? _progressLoadFuture;

  @override
  void initState() {
    super.initState();
    _authChanges = widget.authRepository.authStateChanges();
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authRepository != widget.authRepository) {
      _authChanges = widget.authRepository.authStateChanges();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: _authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingView();
        }

        if (snapshot.hasError) {
          _handleAuthState(null);
          widget.progressController.clearForSignedOutUser();
          return const WelcomeScreen();
        }

        final streamedUser = snapshot.data;
        final user = _checkedUser?.uid == streamedUser?.uid
            ? _checkedUser
            : streamedUser;
        if (user == null) {
          _checkedUser = null;
          _handleAuthState(null);
          widget.progressController.clearForSignedOutUser();
          return const WelcomeScreen();
        }

        _handleAuthState(user);
        if (!user.isEmailVerified) {
          return EmailVerificationScreen(
            authRepository: widget.authRepository,
            onVerificationChecked: (checkedUser) {
              if (mounted) {
                setState(() {
                  _checkedUser = checkedUser;
                });
              }
            },
          );
        }

        _checkedUser = null;
        return _HydratedHome(
          user: user,
          profileLoadFuture: _ensureProfileLoad(user),
          userProfileRepository: widget.userProfileRepository,
          onProfileCompleted: _reloadProfile,
          onProfileChanged: (profile) {
            if (mounted && _lastUserUid == user.uid) {
              setState(() {
                _profileLoadFuture = SynchronousFuture<UserProfile?>(profile);
              });
            }
          },
          progressLoadProvider: _ensureProgressLoad,
          progressController: widget.progressController,
          authRepository: widget.authRepository,
          contentRepository: widget.contentRepository,
        );
      },
    );
  }

  Future<void> _ensureProgressLoad(AuthUser user, {bool force = false}) {
    if (widget.progressController.hasResolvedProgressFor(user.uid)) {
      return Future<void>.value();
    }

    if (force || _progressLoadUid != user.uid || _progressLoadFuture == null) {
      _progressLoadUid = user.uid;
      _progressLoadFuture = widget.progressController
          .loadPersistedProgressForUser(user.uid);
      if (force && mounted) {
        setState(() {});
      }
    }

    return _progressLoadFuture!;
  }

  Future<UserProfile?> _ensureProfileLoad(AuthUser user) {
    if (_profileLoadUid != user.uid || _profileLoadFuture == null) {
      _profileLoadUid = user.uid;
      _profileLoadFuture = widget.userProfileRepository
          .fetchProfile(user.uid)
          .then((profile) {
            if (profile != null && profile.hasUsername) {
              widget.progressController.hydrateTotalPointsFromProfile(
                uid: user.uid,
                totalPoints: profile.totalPoints,
              );
            }
            return profile;
          });
    }

    return _profileLoadFuture!;
  }

  void _reloadProfile() {
    setState(() {
      _profileLoadUid = null;
      _profileLoadFuture = null;
    });
  }

  void _handleAuthState(AuthUser? user) {
    final previousUserUid = _lastUserUid;
    final nextUserUid = user?.uid;
    _lastUserUid = nextUserUid;

    if (previousUserUid == nextUserUid) {
      return;
    }

    _progressLoadUid = null;
    _progressLoadFuture = null;
    _profileLoadUid = null;
    _profileLoadFuture = null;
    if (nextUserUid == null) {
      widget.progressController.clearForSignedOutUser();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = Navigator.maybeOf(context);
      if (navigator == null || !navigator.mounted) {
        return;
      }

      navigator.popUntil((route) => route.isFirst);
    });
  }
}

class _HydratedHome extends StatelessWidget {
  const _HydratedHome({
    required this.user,
    required this.profileLoadFuture,
    required this.userProfileRepository,
    required this.onProfileCompleted,
    required this.onProfileChanged,
    required this.progressLoadProvider,
    required this.progressController,
    required this.authRepository,
    required this.contentRepository,
  });

  final AuthUser user;
  final Future<UserProfile?> profileLoadFuture;
  final UserProfileRepository userProfileRepository;
  final VoidCallback onProfileCompleted;
  final ValueChanged<UserProfile> onProfileChanged;
  final Future<void> Function(AuthUser user, {bool force}) progressLoadProvider;
  final CategoryProgressController progressController;
  final AuthRepository authRepository;
  final ContentRepository contentRepository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: profileLoadFuture,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState != ConnectionState.done) {
          return const _AuthLoadingView();
        }

        final profile = profileSnapshot.data;
        if (profile == null || !profile.hasUsername) {
          return CompleteProfileScreen(
            user: user,
            userProfileRepository: userProfileRepository,
            onCompleted: onProfileCompleted,
          );
        }

        return _ProgressHydratedHome(
          user: user,
          profile: profile,
          userProfileRepository: userProfileRepository,
          onProfileChanged: onProfileChanged,
          progressLoadFuture: progressLoadProvider(user),
          onProgressRetry: () => progressLoadProvider(user, force: true),
          progressController: progressController,
          authRepository: authRepository,
          contentRepository: contentRepository,
        );
      },
    );
  }
}

class _ProgressHydratedHome extends StatelessWidget {
  const _ProgressHydratedHome({
    required this.user,
    required this.profile,
    required this.userProfileRepository,
    required this.onProfileChanged,
    required this.progressLoadFuture,
    required this.onProgressRetry,
    required this.progressController,
    required this.authRepository,
    required this.contentRepository,
  });

  final AuthUser user;
  final UserProfile profile;
  final UserProfileRepository userProfileRepository;
  final ValueChanged<UserProfile> onProfileChanged;
  final Future<void> progressLoadFuture;
  final VoidCallback onProgressRetry;
  final CategoryProgressController progressController;
  final AuthRepository authRepository;
  final ContentRepository contentRepository;

  @override
  Widget build(BuildContext context) {
    Widget home() {
      return AnimatedBuilder(
        animation: progressController,
        builder: (context, child) {
          return MainAuthenticatedShell(
            authRepository: authRepository,
            userProfile: profile,
            personalTotalPoints:
                progressController.totalPointsForUser(user.uid) ??
                profile.totalPoints,
            userProfileRepository: userProfileRepository,
            onProfileChanged: (changedProfile) {
              progressController.hydrateTotalPointsFromProfile(
                uid: user.uid,
                totalPoints: changedProfile.totalPoints,
              );
              onProfileChanged(changedProfile);
            },
            contentRepository: contentRepository,
            progressController: progressController,
            user: user,
          );
        },
      );
    }

    if (progressController.hasResolvedProgressFor(user.uid)) {
      return home();
    }

    if (progressController.hydratedUserId == user.uid &&
        progressController.hydrationStatus == ProgressHydrationStatus.error) {
      return _ProgressLoadErrorView(onRetry: onProgressRetry);
    }

    return FutureBuilder<void>(
      future: progressLoadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AuthLoadingView();
        }

        if (progressController.hydratedUserId == user.uid &&
            progressController.hydrationStatus ==
                ProgressHydrationStatus.error) {
          return _ProgressLoadErrorView(onRetry: onProgressRetry);
        }

        return home();
      },
    );
  }
}

class _ProgressLoadErrorView extends StatelessWidget {
  const _ProgressLoadErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppInsets.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  color: colors.orangeDark,
                  size: 40,
                  semanticLabel: AppStrings.progressLoadError,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.progressLoadError,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: AppStrings.retry,
                  icon: Icons.refresh_outlined,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: AppInsets.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.checkingSession,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
