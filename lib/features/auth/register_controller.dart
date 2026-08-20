import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_email_validator.dart';

class RegisterController extends ChangeNotifier {
  RegisterController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  static const minPasswordLength = 6;

  final AuthRepository _authRepository;

  bool _isLoading = false;
  AuthUser? _registeredUser;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _submitError;

  bool get isLoading => _isLoading;

  bool get hasRegisteredSuccessfully => _registeredUser != null;

  AuthUser? get registeredUser => _registeredUser;

  String? get emailError => _emailError;

  String? get passwordError => _passwordError;

  String? get confirmPasswordError => _confirmPasswordError;

  String? get submitError => _submitError;

  Future<AuthUser?> submit({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (_isLoading || hasRegisteredSuccessfully) {
      return null;
    }

    final normalizedEmail = email.trim();
    _clearFeedback();
    _validate(
      email: normalizedEmail,
      password: password,
      confirmPassword: confirmPassword,
    );

    if (_hasValidationErrors) {
      notifyListeners();
      return null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authRepository.registerWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      _registeredUser = user;
      return user;
    } on AuthException catch (exception) {
      _submitError = exception.userMessage;
      return null;
    } catch (_) {
      _submitError =
          'No pudimos crear la cuenta. Intenta nuevamente más tarde.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _clearFeedback() {
    _emailError = null;
    _passwordError = null;
    _confirmPasswordError = null;
    _submitError = null;
  }

  void _validate({
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    if (email.isEmpty) {
      _emailError = 'Ingresa tu correo electrónico.';
    } else if (!AuthEmailValidator.hasReasonableFormat(email)) {
      _emailError = 'Ingresa un correo electrónico válido.';
    }

    if (password.isEmpty) {
      _passwordError = 'Ingresa una contraseña.';
    } else if (password.length < minPasswordLength) {
      _passwordError =
          'La contraseña debe tener al menos $minPasswordLength caracteres.';
    }

    if (confirmPassword.isEmpty) {
      _confirmPasswordError = 'Confirma tu contraseña.';
    } else if (confirmPassword != password) {
      _confirmPasswordError = 'Las contraseñas no coinciden.';
    }
  }

  bool get _hasValidationErrors {
    return _emailError != null ||
        _passwordError != null ||
        _confirmPasswordError != null;
  }
}
