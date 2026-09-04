import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/auth_user.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'auth_form_layout.dart';
import 'complete_profile_controller.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({
    required this.user,
    required this.userProfileRepository,
    required this.onCompleted,
    super.key,
  });

  final AuthUser user;
  final UserProfileRepository userProfileRepository;
  final VoidCallback onCompleted;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late final CompleteProfileController _controller;
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = CompleteProfileController(
      repository: widget.userProfileRepository,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final profile = await _controller.submit(
      user: widget.user,
      username: _usernameController.text,
    );
    if (profile != null && profile.hasUsername && mounted) {
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.completeProfileTitle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return AuthFormLayout(
            child: _CompleteProfileCard(
              controller: _controller,
              usernameController: _usernameController,
              onSubmit: _submit,
            ),
          );
        },
      ),
    );
  }
}

class _CompleteProfileCard extends StatelessWidget {
  const _CompleteProfileCard({
    required this.controller,
    required this.usernameController,
    required this.onSubmit,
  });

  final CompleteProfileController controller;
  final TextEditingController usernameController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colors.surfaceStrong,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.completeProfileIntroTitle,
              style: textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.completeProfileIntroBody,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: usernameController,
              enabled: !controller.isLoading && !controller.hasCompletedProfile,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.username],
              autocorrect: false,
              onSubmitted: (_) {
                if (!controller.isLoading && !controller.hasCompletedProfile) {
                  onSubmit();
                }
              },
              decoration: InputDecoration(
                labelText: AppStrings.usernameLabel,
                prefixIcon: const Icon(Icons.alternate_email_outlined),
                errorText: controller.usernameError,
              ),
            ),
            if (controller.submitError != null) ...[
              const SizedBox(height: AppSpacing.md),
              _StatusCard(
                message: controller.submitError!,
                icon: Icons.error_outline,
                color: colors.error,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              button: true,
              label: AppStrings.saveUsername,
              child: ElevatedButton(
                onPressed:
                    controller.isLoading || controller.hasCompletedProfile
                    ? null
                    : onSubmit,
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
                          Icon(Icons.save_outlined),
                          SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              AppStrings.saveUsername,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
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
