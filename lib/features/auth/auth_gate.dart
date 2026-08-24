import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../app/category_progress_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/auth_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../high_level_categories/high_level_categories_screen.dart';
import 'email_verification_screen.dart';
import '../splash/welcome_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.authRepository,
    required this.progressController,
    super.key,
  });

  final AuthRepository authRepository;
  final CategoryProgressController progressController;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastUserUid;
  AuthUser? _checkedUser;
  String? _progressLoadUid;
  Future<void>? _progressLoadFuture;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: widget.authRepository.authStateChanges(),
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
          progressLoadFuture: _ensureProgressLoad(user),
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

  void _handleAuthState(AuthUser? user) {
    final previousUserUid = _lastUserUid;
    final nextUserUid = user?.uid;
    _lastUserUid = nextUserUid;

    if (previousUserUid == nextUserUid) {
      return;
    }

    _progressLoadUid = null;
    _progressLoadFuture = null;

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
    required this.progressLoadFuture,
    required this.progressController,
    required this.authRepository,
  });

  final AuthUser user;
  final Future<void> progressLoadFuture;
  final CategoryProgressController progressController;
  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    if (progressController.hasResolvedProgressFor(user.uid)) {
      return HighLevelCategoriesScreen(
        authRepository: authRepository,
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
