import 'package:demo_yomecuido/data/models/username.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Username', () {
    test('normalizes by trimming and lowercasing', () {
      expect(Username.normalize(' DiegoNais '), 'diegonais');
    });

    test('accepts valid lengths and characters', () {
      expect(Username.validate('abc'), isNull);
      expect(Username.validate('abcdefghijklmnopqrst'), isNull);
      expect(Username.validate('diego_n.2026'), isNull);
      expect(Username.validate('Diego23'), isNull);
    });

    test('rejects invalid lengths', () {
      expect(Username.validate('ab'), UsernameValidationError.invalidLength);
      expect(
        Username.validate('abcdefghijklmnopqrstu'),
        UsernameValidationError.invalidLength,
      );
    });

    test('rejects spaces and unsupported characters', () {
      expect(
        Username.validate('diego nais'),
        UsernameValidationError.invalidCharacters,
      );
      expect(
        Username.validate('diego@'),
        UsernameValidationError.invalidCharacters,
      );
      expect(
        Username.validate('diego#'),
        UsernameValidationError.invalidCharacters,
      );
    });
  });
}
