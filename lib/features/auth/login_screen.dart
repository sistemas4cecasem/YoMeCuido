import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'login_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController _controller;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = LoginController(authRepository: widget.authRepository);
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _controller.submit(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  void _openRegister() {
    Navigator.of(context).pushNamed(AppRoutes.register);
  }

  void _openForgotPassword() {
    Navigator.of(context).pushNamed(AppRoutes.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.loginTitle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _LoginIntro(),
                const SizedBox(height: AppSpacing.lg),
                _LoginFormCard(
                  controller: _controller,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  isPasswordVisible: _isPasswordVisible,
                  onTogglePasswordVisibility: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                  onSubmit: _submit,
                  onOpenRegister: _openRegister,
                  onOpenForgotPassword: _openForgotPassword,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoginIntro extends StatelessWidget {
  const _LoginIntro();

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
            Icon(Icons.login_outlined, color: colors.orangeDark),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.loginIntroTitle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(AppStrings.loginIntroBody, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.controller,
    required this.emailController,
    required this.passwordController,
    required this.isPasswordVisible,
    required this.onTogglePasswordVisibility,
    required this.onSubmit,
    required this.onOpenRegister,
    required this.onOpenForgotPassword,
  });

  final LoginController controller;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isPasswordVisible;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onSubmit;
  final VoidCallback onOpenRegister;
  final VoidCallback onOpenForgotPassword;

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
                  !controller.isLoading && !controller.hasSignedInSuccessfully,
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
                  !controller.isLoading && !controller.hasSignedInSuccessfully,
              obscureText: !isPasswordVisible,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) {
                if (!controller.isLoading &&
                    !controller.hasSignedInSuccessfully) {
                  onSubmit();
                }
              },
              decoration: InputDecoration(
                labelText: AppStrings.passwordLabel,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: isPasswordVisible
                      ? AppStrings.hidePassword
                      : AppStrings.showPassword,
                  onPressed:
                      controller.isLoading || controller.hasSignedInSuccessfully
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
            if (controller.submitError != null) ...[
              const SizedBox(height: AppSpacing.md),
              _LoginStatusCard(
                message: controller.submitError!,
                icon: Icons.error_outline,
                color: colors.error,
              ),
            ],
            if (controller.hasSignedInSuccessfully) ...[
              const SizedBox(height: AppSpacing.md),
              _LoginStatusCard(
                message: AppStrings.loginSuccessMessage,
                icon: Icons.check_circle_outline,
                color: colors.success,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _LoginButton(controller: controller, onSubmit: onSubmit),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed:
                  controller.isLoading || controller.hasSignedInSuccessfully
                  ? null
                  : onOpenForgotPassword,
              child: const Text(AppStrings.forgotPasswordPrompt),
            ),
            TextButton(
              onPressed:
                  controller.isLoading || controller.hasSignedInSuccessfully
                  ? null
                  : onOpenRegister,
              child: const Text(AppStrings.createAccountPrompt),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.controller, required this.onSubmit});

  final LoginController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isDisabled =
        controller.isLoading || controller.hasSignedInSuccessfully;

    return Semantics(
      button: true,
      label: AppStrings.loginAction,
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
                    Icon(Icons.login_outlined),
                    SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        AppStrings.loginAction,
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

class _LoginStatusCard extends StatelessWidget {
  const _LoginStatusCard({
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
