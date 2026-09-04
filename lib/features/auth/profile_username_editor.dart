import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/username.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_profile_repository.dart';

class ProfileUsernameEditor extends StatefulWidget {
  const ProfileUsernameEditor({
    required this.uid,
    required this.profile,
    required this.authRepository,
    required this.repository,
    required this.onChanged,
    super.key,
  });

  final String uid;
  final UserProfile profile;
  final AuthRepository authRepository;
  final UserProfileRepository repository;
  final ValueChanged<UserProfile> onChanged;

  @override
  State<ProfileUsernameEditor> createState() => _ProfileUsernameEditorState();
}

class _ProfileUsernameEditorState extends State<ProfileUsernameEditor> {
  late UserProfile _profile = widget.profile;
  late final TextEditingController _text = TextEditingController(
    text: _profile.username,
  );
  bool _editing = false;
  bool _saving = false;
  String? _error;
  bool _saved = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final validation = Username.validate(_text.text);
    final user = widget.authRepository.currentUser;
    setState(() {
      _error = validation?.userMessage;
      _saved = false;
    });
    if (validation != null) return;
    if (user == null || user.uid != widget.uid) {
      setState(() => _error = AppStrings.usernameUpdateError);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final profile = await widget.repository.changeUsername(
        uid: user.uid,
        email: user.email,
        username: _text.text,
      );
      if (widget.authRepository.currentUser?.uid != user.uid) return;
      // Keep the parent current even if the dialog was closed during the write.
      widget.onChanged(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _editing = false;
        _saved = true;
      });
    } on UserProfileException catch (exception) {
      exception.logForDebug();
      if (mounted) setState(() => _error = exception.userMessage);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.usernameUpdateError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_editing)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.profileUsername,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _profile.username ?? '-',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppStrings.changeUsername,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => setState(() {
                  _text.text = _profile.username ?? '';
                  _editing = true;
                  _error = null;
                  _saved = false;
                }),
              ),
            ],
          )
        else ...[
          TextField(
            controller: _text,
            enabled: !_saving,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              labelText: AppStrings.usernameLabel,
              prefixIcon: Icon(Icons.alternate_email_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text(AppStrings.saveUsername),
              ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _editing = false;
                        _error = null;
                      }),
                child: const Text(AppStrings.cancel),
              ),
            ],
          ),
        ],
        if (_error != null || _saved) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _error != null
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  color: _error != null ? colors.error : colors.success,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(_error ?? AppStrings.usernameUpdated)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
