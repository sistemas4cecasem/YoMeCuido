import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'auth_form_layout.dart';
import 'register_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final RegisterController _controller;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = RegisterController(authRepository: widget.authRepository);
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _controller.submit(
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.registerTitle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return AuthFormLayout(
            child: _RegisterFormCard(
              controller: _controller,
              emailController: _emailController,
              passwordController: _passwordController,
              confirmPasswordController: _confirmPasswordController,
              isPasswordVisible: _isPasswordVisible,
              isConfirmPasswordVisible: _isConfirmPasswordVisible,
              onTogglePasswordVisibility: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
              onToggleConfirmPasswordVisibility: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
              onSubmit: _submit,
            ),
          );
        },
      ),
    );
  }
}

class _RegisterFormCard extends StatelessWidget {
  const _RegisterFormCard({
    required this.controller,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isPasswordVisible,
    required this.isConfirmPasswordVisible,
    required this.onTogglePasswordVisibility,
    required this.onToggleConfirmPasswordVisibility,
    required this.onSubmit,
  });

  final RegisterController controller;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isPasswordVisible;
  final bool isConfirmPasswordVisible;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onToggleConfirmPasswordVisibility;
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
                  !controller.isLoading &&
                  !controller.hasRegisteredSuccessfully,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              decoration: InputDecoration(
                labelText: AppStrings.emailLabel,
                prefixIcon: const Icon(Icons.mail_outline),
                errorText: controller.emailError,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passwordController,
              enabled:
                  !controller.isLoading &&
                  !controller.hasRegisteredSuccessfully,
              obscureText: !isPasswordVisible,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: AppStrings.passwordLabel,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: isPasswordVisible
                      ? AppStrings.hidePassword
                      : AppStrings.showPassword,
                  onPressed:
                      controller.isLoading ||
                          controller.hasRegisteredSuccessfully
                      ? null
                      : onTogglePasswordVisibility,
                  icon: Icon(
                    isPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                errorText: controller.passwordError,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: confirmPasswordController,
              enabled:
                  !controller.isLoading &&
                  !controller.hasRegisteredSuccessfully,
              obscureText: !isConfirmPasswordVisible,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) {
                if (!controller.isLoading &&
                    !controller.hasRegisteredSuccessfully) {
                  onSubmit();
                }
              },
              decoration: InputDecoration(
                labelText: AppStrings.confirmPasswordLabel,
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                suffixIcon: IconButton(
                  tooltip: isConfirmPasswordVisible
                      ? AppStrings.hidePassword
                      : AppStrings.showPassword,
                  onPressed:
                      controller.isLoading ||
                          controller.hasRegisteredSuccessfully
                      ? null
                      : onToggleConfirmPasswordVisibility,
                  icon: Icon(
                    isConfirmPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                errorText: controller.confirmPasswordError,
              ),
            ),
            if (controller.submitError != null) ...[
              const SizedBox(height: AppSpacing.md),
              _RegisterStatusCard(
                message: controller.submitError!,
                icon: Icons.error_outline,
                color: colors.error,
              ),
            ],
            if (controller.hasRegisteredSuccessfully) ...[
              const SizedBox(height: AppSpacing.md),
              _RegisterStatusCard(
                message: AppStrings.registerSuccessMessage,
                icon: Icons.check_circle_outline,
                color: colors.success,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _RegisterButton(controller: controller, onSubmit: onSubmit),
          ],
        ),
      ),
    );
  }
}

class _RegisterButton extends StatelessWidget {
  const _RegisterButton({required this.controller, required this.onSubmit});

  final RegisterController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isDisabled =
        controller.isLoading || controller.hasRegisteredSuccessfully;

    return Semantics(
      button: true,
      label: AppStrings.createAccount,
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
                    Icon(Icons.person_add_alt_outlined),
                    SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        AppStrings.createAccount,
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

class _RegisterStatusCard extends StatelessWidget {
  const _RegisterStatusCard({
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
