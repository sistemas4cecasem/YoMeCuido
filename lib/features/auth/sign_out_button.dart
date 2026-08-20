import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../data/repositories/auth_repository.dart';
import '../../shared/feedback/app_dialog.dart';
import '../../shared/feedback/app_toast.dart';

class SignOutButton extends StatefulWidget {
  const SignOutButton({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<SignOutButton> {
  bool _isSigningOut = false;

  Future<void> _confirmAndSignOut() async {
    if (_isSigningOut) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    final shouldSignOut = await AppDialog.showConfirmation(
      context,
      title: AppStrings.signOutTitle,
      message: AppStrings.signOutBody,
      cancelLabel: AppStrings.cancel,
      confirmLabel: AppStrings.signOut,
      icon: Icons.logout_outlined,
      isDestructiveConfirm: true,
    );

    if (!mounted) {
      return;
    }

    if (!shouldSignOut) {
      setState(() {
        _isSigningOut = false;
      });
      return;
    }

    try {
      await widget.authRepository.signOut();
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppToast.showError(context, AppStrings.signOutError);
      setState(() {
        _isSigningOut = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.signOut,
      child: IconButton(
        tooltip: AppStrings.signOut,
        onPressed: _isSigningOut ? null : _confirmAndSignOut,
        icon: _isSigningOut
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(Icons.logout_outlined),
      ),
    );
  }
}
