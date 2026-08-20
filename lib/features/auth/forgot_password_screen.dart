import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'forgot_password_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final ForgotPasswordController _controller;
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = ForgotPasswordController(
      authRepository: widget.authRepository,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _controller.submit(email: _emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.forgotPasswordTitle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ForgotPasswordIntro(),
                const SizedBox(height: AppSpacing.lg),
                _ForgotPasswordFormCard(
                  controller: _controller,
                  emailController: _emailController,
                  onSubmit: _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ForgotPasswordIntro extends StatelessWidget {
  const _ForgotPasswordIntro();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colors.orangeSoft,
      child: Padding(
        padding: AppInsets.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.mark_email_read_outlined, color: colors.orangeDark),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.forgotPasswordIntroTitle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.forgotPasswordIntroBody,
                    style: textTheme.bodyMedium,
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

class _ForgotPasswordFormCard extends StatelessWidget {
  const _ForgotPasswordFormCard({
    required this.controller,
    required this.emailController,
    required this.onSubmit,
  });

  final ForgotPasswordController controller;
  final TextEditingController emailController;
  final VoidCallback onSubmit;

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
            TextField(
              controller: emailController,
              enabled:
                  !controller.isLoading && !controller.hasSubmittedSuccessfully,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              onSubmitted: (_) {
                if (!controller.isLoading &&
                    !controller.hasSubmittedSuccessfully) {
                  onSubmit();
                }
              },
              decoration: InputDecoration(
                labelText: AppStrings.emailLabel,
                prefixIcon: const Icon(Icons.mail_outline),
                errorText: controller.emailError,
              ),
            ),
            if (controller.submitError != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ForgotPasswordStatusCard(
                message: controller.submitError!,
                icon: Icons.error_outline,
                color: colors.error,
              ),
            ],
            if (controller.hasSubmittedSuccessfully) ...[
              const SizedBox(height: AppSpacing.md),
              _ForgotPasswordStatusCard(
                message: AppStrings.forgotPasswordSuccessMessage,
                icon: Icons.check_circle_outline,
                color: colors.success,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _ForgotPasswordButton(controller: controller, onSubmit: onSubmit),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text(AppStrings.backToLogin),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordButton extends StatelessWidget {
  const _ForgotPasswordButton({
    required this.controller,
    required this.onSubmit,
  });

  final ForgotPasswordController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isDisabled =
        controller.isLoading || controller.hasSubmittedSuccessfully;

    return Semantics(
      button: true,
      label: AppStrings.requestPasswordReset,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isDisabled ? null : onSubmit,
          child: controller.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mark_email_read_outlined),
                    SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        AppStrings.requestPasswordReset,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ForgotPasswordStatusCard extends StatelessWidget {
  const _ForgotPasswordStatusCard({
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

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
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
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
