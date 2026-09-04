import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../high_level_categories/high_level_categories_screen.dart';
import 'complete_profile_screen.dart';
import 'email_verification_screen.dart';
import '../splash/welcome_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.authRepository,
    required this.userProfileRepository,
    required this.progressController,
    super.key,
  });

  final AuthRepository authRepository;
  final UserProfileRepository userProfileRepository;
  final CategoryProgressController progressController;

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
                _profileLoadFuture = Future.value(profile);
              });
            }
          },
          progressLoadProvider: _ensureProgressLoad,
          progressController: widget.progressController,
          authRepository: widget.authRepository,
        );
      },
    );
  }

  Future<void> _ensureProgressLoad(AuthUser user) {
    if (widget.progressController.hasResolvedProgressFor(user.uid)) {
      return Future<void>.value();
    }

    if (_progressLoadUid != user.uid || _progressLoadFuture == null) {
      _progressLoadUid = user.uid;
      _progressLoadFuture = widget.progressController
          .loadPersistedProgressForUser(user.uid);
    }

    return _progressLoadFuture!;
  }

  Future<UserProfile?> _ensureProfileLoad(AuthUser user) {
    if (_profileLoadUid != user.uid || _profileLoadFuture == null) {
      _profileLoadUid = user.uid;
      _profileLoadFuture = widget.userProfileRepository.fetchProfile(user.uid);
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
  });

  final AuthUser user;
  final Future<UserProfile?> profileLoadFuture;
  final UserProfileRepository userProfileRepository;
  final VoidCallback onProfileCompleted;
  final ValueChanged<UserProfile> onProfileChanged;
  final Future<void> Function(AuthUser user) progressLoadProvider;
  final CategoryProgressController progressController;
  final AuthRepository authRepository;

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
          progressController: progressController,
          authRepository: authRepository,
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
    required this.progressController,
    required this.authRepository,
  });

  final AuthUser user;
  final UserProfile profile;
  final UserProfileRepository userProfileRepository;
  final ValueChanged<UserProfile> onProfileChanged;
  final Future<void> progressLoadFuture;
  final CategoryProgressController progressController;
  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    if (progressController.hasResolvedProgressFor(user.uid)) {
      return HighLevelCategoriesScreen(
        authRepository: authRepository,
        userProfile: profile,
        userProfileRepository: userProfileRepository,
        onProfileChanged: onProfileChanged,
        showBackButton: false,
      );
    }

    return FutureBuilder<void>(
      future: progressLoadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AuthLoadingView();
        }

        return HighLevelCategoriesScreen(
          authRepository: authRepository,
          userProfile: profile,
          userProfileRepository: userProfileRepository,
          onProfileChanged: onProfileChanged,
          showBackButton: false,
        );
      },
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
