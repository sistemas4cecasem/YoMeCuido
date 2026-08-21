import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/auth_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/feedback/app_toast.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/secondary_button.dart';
import 'auth_form_layout.dart';
import 'sign_out_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    required this.authRepository,
    required this.onVerificationChecked,
    super.key,
  });

  final AuthRepository authRepository;
  final ValueChanged<AuthUser?> onVerificationChecked;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  String? _message;
  bool _isError = false;

  Future<void> _checkVerification() async {
    if (_isChecking || _isResending) {
      return;
    }

    setState(() {
      _isChecking = true;
      _message = null;
      _isError = false;
    });

    try {
      final user = await widget.authRepository.reloadCurrentUser();
      widget.onVerificationChecked(user);
      if (mounted && user?.isEmailVerified != true) {
        setState(() {
          _message = AppStrings.emailVerificationPending;
          _isError = true;
        });
        AppToast.showWarning(context, AppStrings.emailVerificationPending);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = AppStrings.emailVerificationError;
          _isError = true;
        });
        AppToast.showError(context, AppStrings.emailVerificationError);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _resendVerification() async {
    if (_isChecking || _isResending) {
      return;
    }

    setState(() {
      _isResending = true;
      _message = null;
      _isError = false;
    });

    try {
      await widget.authRepository.sendEmailVerification();
      if (mounted) {
        setState(() {
          _message = AppStrings.emailVerificationSent;
        });
        AppToast.showSuccess(context, AppStrings.emailVerificationSent);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = AppStrings.emailVerificationError;
          _isError = true;
        });
        AppToast.showError(context, AppStrings.emailVerificationError);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.emailVerificationTitle,
      automaticallyImplyLeading: false,
      actions: [SignOutButton(authRepository: widget.authRepository)],
      child: AuthFormLayout(
        child: Card(
          color: context.colors.surfaceStrong,
          child: Padding(
            padding: AppInsets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: context.colors.orangeDark,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.emailVerificationBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_message != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _VerificationMessage(message: _message!, isError: _isError),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: AppStrings.emailVerificationCheck,
                  icon: _isChecking ? null : Icons.check_circle_outline,
                  onPressed: _isChecking || _isResending
                      ? null
                      : _checkVerification,
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: AppStrings.emailVerificationResend,
                  icon: _isResending ? null : Icons.refresh_outlined,
                  onPressed: _isChecking || _isResending
                      ? null
                      : _resendVerification,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationMessage extends StatelessWidget {
  const _VerificationMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = isError ? colors.error : colors.success;

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: color),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: color,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
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
