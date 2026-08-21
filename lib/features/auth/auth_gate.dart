import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/auth_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../high_level_categories/high_level_categories_screen.dart';
import 'email_verification_screen.dart';
import '../splash/welcome_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _lastHadUser;
  AuthUser? _checkedUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: widget.authRepository.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingView();
        }

        if (snapshot.hasError) {
          _handleAuthState(false);
          return const WelcomeScreen();
        }

        final streamedUser = snapshot.data;
        final user = _checkedUser?.uid == streamedUser?.uid
            ? _checkedUser
            : streamedUser;
        if (user == null) {
          _checkedUser = null;
          _handleAuthState(false);
          return const WelcomeScreen();
        }

        _handleAuthState(true);
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
        return HighLevelCategoriesScreen(
          authRepository: widget.authRepository,
          showBackButton: false,
        );
      },
    );
  }

  void _handleAuthState(bool hasUser) {
    final lastHadUser = _lastHadUser;
    _lastHadUser = hasUser;

    if (lastHadUser == null || lastHadUser == hasUser) {
      return;
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
