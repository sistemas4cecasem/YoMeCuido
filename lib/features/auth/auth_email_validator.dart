abstract final class AuthEmailValidator {
  static bool hasReasonableFormat(String email) {
    final atIndex = email.indexOf('@');
    final lastDotIndex = email.lastIndexOf('.');

    return atIndex > 0 &&
        lastDotIndex > atIndex + 1 &&
        lastDotIndex < email.length - 1;
  }
}
