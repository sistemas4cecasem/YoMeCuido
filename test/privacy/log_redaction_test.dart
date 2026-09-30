import 'package:demo_yomecuido/data/repositories/category_progress_repository.dart';
import 'package:demo_yomecuido/data/repositories/user_profile_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('technical exception details stay out of logs and visible messages', () {
    const secret = 'uid-persona@example.com-token';
    const profileError = UserProfileException(
      UserProfileFailureReason.invalidUsername,
      operation: UserProfileFailureOperation.create,
      technicalMessage: secret,
      stackTrace: _SecretTrace(),
    );
    const progressError = CategoryProgressException(
      CategoryProgressFailureReason.firebase,
      operation: CategoryProgressFailureOperation.fetchAllProgress,
      technicalMessage: secret,
      stackTrace: _SecretTrace(),
    );
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => messages.add(message ?? '');
    try {
      profileError.logForDebug();
      progressError.logForDebug();
    } finally {
      debugPrint = original;
    }
    expect(messages.join(), isNot(contains(secret)));
    expect(profileError.toString(), isNot(contains(secret)));
    expect(progressError.toString(), isNot(contains(secret)));
    expect(profileError.userMessage, isNot(contains(secret)));
  });
}

class _SecretTrace implements StackTrace {
  const _SecretTrace();

  @override
  String toString() => 'uid-persona@example.com-token';
}
