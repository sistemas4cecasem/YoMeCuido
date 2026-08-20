import 'package:flutter/foundation.dart';

import '../../data/repositories/auth_repository.dart';
import 'auth_email_validator.dart';

class ForgotPasswordController extends ChangeNotifier {
  ForgotPasswordController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  bool _isLoading = false;
  bool _hasSubmittedSuccessfully = false;
  String? _emailError;
  String? _submitError;

  bool get isLoading => _isLoading;

  bool get hasSubmittedSuccessfully => _hasSubmittedSuccessfully;

  String? get emailError => _emailError;

  String? get submitError => _submitError;

  Future<bool> submit({required String email}) async {
    if (_isLoading || _hasSubmittedSuccessfully) {
      return false;
    }

    final normalizedEmail = email.trim();
    _clearFeedback();
    _validateEmail(normalizedEmail);

    if (_emailError != null) {
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.sendPasswordResetEmail(email: normalizedEmail);
      _hasSubmittedSuccessfully = true;
      return true;
    } on AuthException catch (exception) {
      if (exception.reason == AuthFailureReason.userNotFound) {
        _hasSubmittedSuccessfully = true;
        return true;
      }

      _submitError = exception.userMessage;
      return false;
    } catch (_) {
      _submitError =
          'No pudimos solicitar la recuperación. Intenta nuevamente.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _clearFeedback() {
    _emailError = null;
    _submitError = null;
  }

  void _validateEmail(String email) {
    if (email.isEmpty) {
      _emailError = 'Ingresa tu correo electrónico.';
    } else if (!AuthEmailValidator.hasReasonableFormat(email)) {
      _emailError = 'Ingresa un correo electrónico válido.';
    }
  }
}
