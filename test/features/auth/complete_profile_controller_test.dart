import 'package:demo_yomecuido/data/models/auth_user.dart';
import 'package:demo_yomecuido/data/models/user_profile.dart';
import 'package:demo_yomecuido/data/repositories/user_profile_repository.dart';
import 'package:demo_yomecuido/features/auth/complete_profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompleteProfileController', () {
    test('validates username before calling repository', () async {
      final repository = _FakeUserProfileRepository();
      final controller = CompleteProfileController(repository: repository);

      final profile = await controller.submit(
        user: const AuthUser(uid: 'uid-123', email: 'persona@example.com'),
        username: 'diego nais',
      );

      expect(profile, isNull);
      expect(repository.completeCallCount, 0);
      expect(
        controller.usernameError,
        'Solo puedes utilizar letras, números, punto y guion bajo.',
      );
    });

    test('stores completed profile', () async {
      final repository = _FakeUserProfileRepository();
      final controller = CompleteProfileController(repository: repository);

      final profile = await controller.submit(
        user: const AuthUser(uid: 'uid-123', email: 'persona@example.com'),
        username: 'DiegoNais',
      );

      expect(profile?.username, 'DiegoNais');
      expect(controller.hasCompletedProfile, isTrue);
      expect(repository.completeCallCount, 1);
    });

    test('shows username occupied error', () async {
      final repository = _FakeUserProfileRepository(
        exception: const UserProfileException(
          UserProfileFailureReason.usernameAlreadyInUse,
          operation: UserProfileFailureOperation.reserveUsername,
        ),
      );
      final controller = CompleteProfileController(repository: repository);

      final profile = await controller.submit(
        user: const AuthUser(uid: 'uid-123', email: 'persona@example.com'),
        username: 'DiegoNais',
      );

      expect(profile, isNull);
      expect(controller.submitError, 'Este nombre de usuario ya está en uso.');
    });
  });
}

class _FakeUserProfileRepository extends UserProfileRepository {
  _FakeUserProfileRepository({this.exception}) : super.testing();

  final UserProfileException? exception;
  int completeCallCount = 0;

  @override
  Future<UserProfile> completeProfile({
    required String uid,
    required String? email,
    required String username,
  }) async {
    completeCallCount += 1;
    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }

    return UserProfile(
      username: username,
      usernameNormalized: username.toLowerCase(),
      email: email ?? 'persona@example.com',
      role: UserProfileRole.user,
      createdAt: null,
      updatedAt: null,
    );
  }
}
