import 'package:flutter_test/flutter_test.dart';
import 'package:hami_guide/core/services/google_auth_service.dart';

void main() {
  group('GoogleAuthService', () {
    test('uses the registered Android callback URI', () {
      final uri = Uri.parse(GoogleAuthService.redirectUrl);

      expect(uri.scheme, 'com.awadhobaid.dalilalhami');
      expect(uri.host, 'login-callback');
      expect(uri.path, '/');
    });
  });
}
