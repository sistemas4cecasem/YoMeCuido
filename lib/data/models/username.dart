class Username {
  const Username._();

  static const minLength = 3;
  static const maxLength = 20;
  static final RegExp _allowedPattern = RegExp(r'^[a-zA-Z0-9._]{3,20}$');

  static String normalize(String value) {
    return value.trim().toLowerCase();
  }

  static UsernameValidationError? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.length < minLength || trimmed.length > maxLength) {
      return UsernameValidationError.invalidLength;
    }
    if (!_allowedPattern.hasMatch(trimmed)) {
      return UsernameValidationError.invalidCharacters;
    }
    return null;
  }

  static bool isValid(String value) => validate(value) == null;
}

enum UsernameValidationError {
  invalidLength,
  invalidCharacters;

  String get userMessage {
    return switch (this) {
      UsernameValidationError.invalidLength =>
        'El nombre de usuario debe tener entre 3 y 20 caracteres.',
      UsernameValidationError.invalidCharacters =>
        'Solo puedes utilizar letras, números, punto y guion bajo.',
    };
  }
}
