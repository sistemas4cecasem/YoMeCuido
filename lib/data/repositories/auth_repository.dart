import '../models/auth_user.dart';

abstract class AuthRepository {
  AuthUser? get currentUser;

  Stream<AuthUser?> authStateChanges();

  Future<AuthUser> registerWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> sendEmailVerification();

  Future<AuthUser?> reloadCurrentUser();
}

enum AuthFailureReason {
  invalidEmail,
  userNotFound,
  wrongPassword,
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  userDisabled,
  operationNotAllowed,
  tooManyRequests,
  networkRequestFailed,
  userProfileUnavailable,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.reason);

  factory AuthException.fromFirebaseCode(String code) {
    return AuthException(switch (code) {
      'invalid-email' => AuthFailureReason.invalidEmail,
      'user-not-found' => AuthFailureReason.userNotFound,
      'wrong-password' => AuthFailureReason.wrongPassword,
      'invalid-credential' => AuthFailureReason.invalidCredentials,
      'email-already-in-use' => AuthFailureReason.emailAlreadyInUse,
      'weak-password' => AuthFailureReason.weakPassword,
      'user-disabled' => AuthFailureReason.userDisabled,
      'operation-not-allowed' => AuthFailureReason.operationNotAllowed,
      'too-many-requests' => AuthFailureReason.tooManyRequests,
      'network-request-failed' => AuthFailureReason.networkRequestFailed,
      _ => AuthFailureReason.unknown,
    });
  }

  final AuthFailureReason reason;

  String get userMessage {
    return switch (reason) {
      AuthFailureReason.invalidEmail => 'El correo electrónico no es válido.',
      AuthFailureReason.userNotFound =>
        'No encontramos una cuenta con ese correo.',
      AuthFailureReason.wrongPassword => 'La contraseña no es correcta.',
      AuthFailureReason.invalidCredentials =>
        'Las credenciales ingresadas no son válidas.',
      AuthFailureReason.emailAlreadyInUse => 'Este correo ya está registrado.',
      AuthFailureReason.weakPassword => 'La contraseña debe ser más segura.',
      AuthFailureReason.userDisabled =>
        'Esta cuenta se encuentra deshabilitada.',
      AuthFailureReason.operationNotAllowed =>
        'Esta operación no está disponible en este momento.',
      AuthFailureReason.tooManyRequests =>
        'Hay demasiados intentos. Intenta nuevamente más tarde.',
      AuthFailureReason.networkRequestFailed =>
        'No pudimos conectar con el servicio. Revisa tu conexión.',
      AuthFailureReason.userProfileUnavailable =>
        'No pudimos preparar tu perfil. Intenta nuevamente.',
      AuthFailureReason.unknown =>
        'No pudimos completar la operación. Intenta nuevamente.',
    };
  }

  @override
  String toString() => userMessage;
}
