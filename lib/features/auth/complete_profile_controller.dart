import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/username.dart';
import '../../data/repositories/user_profile_repository.dart';

class CompleteProfileController extends ChangeNotifier {
  CompleteProfileController({required UserProfileRepository repository})
    : _repository = repository;

  final UserProfileRepository _repository;

  bool _isLoading = false;
  UserProfile? _profile;
  String? _usernameError;
  String? _submitError;

  bool get isLoading => _isLoading;

  UserProfile? get profile => _profile;

  bool get hasCompletedProfile => _profile?.hasUsername ?? false;

  String? get usernameError => _usernameError;

  String? get submitError => _submitError;

  Future<UserProfile?> submit({
    required AuthUser user,
    required String username,
  }) async {
    if (_isLoading || hasCompletedProfile) {
      return null;
    }

    _clearFeedback();
    final usernameError = Username.validate(username);
    if (usernameError != null) {
      _usernameError = usernameError.userMessage;
      notifyListeners();
      return null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _repository.completeProfile(
        uid: user.uid,
        email: user.email,
        username: username.trim(),
      );
      _profile = profile;
      return profile;
    } on UserProfileException catch (exception) {
      _submitError = exception.userMessage;
      return null;
    } catch (_) {
      _submitError = 'No pudimos actualizar tu perfil. Intenta nuevamente.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _clearFeedback() {
    _usernameError = null;
    _submitError = null;
  }
}
