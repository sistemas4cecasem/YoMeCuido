import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_email_validator.dart';

class LoginController extends ChangeNotifier {
  LoginController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  bool _isLoading = false;
  AuthUser? _signedInUser;
  String? _emailError;
  String? _passwordError;
  String? _submitError;

  bool get isLoading => _isLoading;

  bool get hasSignedInSuccessfully => _signedInUser != null;

  AuthUser? get signedInUser => _signedInUser;

  String? get emailError => _emailError;

  String? get passwordError => _passwordError;

  String? get submitError => _submitError;

  Future<AuthUser?> submit({
    required String email,
    required String password,
  }) async {
    if (_isLoading || hasSignedInSuccessfully) {
      return null;
    }

    final normalizedEmail = email.trim();
    _clearFeedback();
    _validate(email: normalizedEmail, password: password);

    if (_hasValidationErrors) {
      notifyListeners();
      return null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authRepository.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      _signedInUser = user;
      return user;
    } on AuthException catch (exception) {
      _submitError = exception.userMessage;
      return null;
    } catch (_) {
      _submitError = 'No pudimos iniciar sesión. Intenta nuevamente más tarde.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _clearFeedback() {
    _emailError = null;
    _passwordError = null;
    _submitError = null;
  }

  void _validate({required String email, required String password}) {
    if (email.isEmpty) {
      _emailError = 'Ingresa tu correo electrónico.';
    } else if (!AuthEmailValidator.hasReasonableFormat(email)) {
      _emailError = 'Ingresa un correo electrónico válido.';
    }

    if (password.isEmpty) {
      _passwordError = 'Ingresa tu contraseña.';
    }
  }

  bool get _hasValidationErrors {
    return _emailError != null || _passwordError != null;
  }
}
