import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/account_deletion_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/widgets/primary_button.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({
    required this.service,
    required this.authRepository,
    this.recovery = false,
    this.profileMissing = false,
    super.key,
  });

  final AccountDeletionService service;
  final AuthRepository authRepository;
  final bool recovery;
  final bool profileMissing;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _durable = false;
  bool _profileMissing = false;
  bool _needsPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _durable = widget.recovery;
    _profileMissing = widget.profileMissing;
    _needsPassword = !widget.recovery || widget.profileMissing;
    if (widget.recovery && !widget.profileMissing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_busy) return;
    final password = _passwordController.text;
    if (_needsPassword && password.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_durable) {
        await widget.service.start(password);
      } else if (_profileMissing && _needsPassword) {
        await widget.service.retryAuthOnly(password);
      } else {
        await widget.service.resume();
      }
    } on AccountDeletionException catch (error) {
      await _handleFailure(error);
    } catch (_) {
      await _handleFailure(
        const AccountDeletionException(AccountDeletionFailure.remote),
      );
    } finally {
      if (mounted) {
        _passwordController.clear();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleFailure(AccountDeletionException error) async {
    try {
      final profile = await widget.service.inspectCurrentProfile();
      if (profile == null) {
        _durable = true;
        _profileMissing = true;
      } else if (profile.state == AccountState.deleting) {
        _durable = true;
      }
    } catch (_) {
      // Keep the current screen until the remote state can be read again.
    }
    if (!mounted) return;
    setState(() {
      _needsPassword =
          error.reason == AccountDeletionFailure.password ||
          error.reason == AccountDeletionFailure.recentLogin ||
          _profileMissing;
      _error = error.userMessage;
    });
  }

  Future<void> _signOut() async {
    try {
      await widget.authRepository.signOut();
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.signOutError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopScope(
      canPop: !_durable && !_busy,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(
            _durable
                ? AppStrings.deletionFinishTitle
                : AppStrings.deleteAccount,
          ),
          automaticallyImplyLeading: !_durable,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: AppInsets.screen,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: AppInsets.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_forever_outlined,
                          color: colors.error,
                          size: 40,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _durable
                              ? AppStrings.deletionInProgress
                              : AppStrings.deletionPasswordPrompt,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_profileMissing)
                          const Text(AppStrings.deletionAuthOnlyBody),
                        if (_needsPassword) ...[
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            enabled: !_busy,
                            autofillHints: const [AutofillHints.password],
                            decoration: const InputDecoration(
                              labelText: AppStrings.deletionPasswordLabel,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _run(),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(_error!, style: TextStyle(color: colors.error)),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        PrimaryButton(
                          label: _durable
                              ? AppStrings.deletionContinue
                              : AppStrings.deleteAccount,
                          icon: Icons.delete_forever_outlined,
                          onPressed:
                              _busy ||
                                  (_needsPassword &&
                                      _passwordController.text.isEmpty)
                              ? null
                              : _run,
                        ),
                        if (_busy) ...[
                          const SizedBox(height: AppSpacing.md),
                          const Center(child: CircularProgressIndicator()),
                          const Text(
                            AppStrings.deletionBusy,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (_durable) ...[
                          const SizedBox(height: AppSpacing.md),
                          TextButton(
                            onPressed: _busy ? null : _signOut,
                            child: const Text(AppStrings.deletionSignOut),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
