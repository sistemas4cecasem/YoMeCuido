class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.isEmailVerified = false,
  });

  final String uid;
  final String? email;
  final bool isEmailVerified;
}
