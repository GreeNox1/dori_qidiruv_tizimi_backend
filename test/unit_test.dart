import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dori_qidiruv_tizimi_backend/config/env_config.dart';
import 'package:dori_qidiruv_tizimi_backend/modules/auth/auth_service.dart';
import 'package:dori_qidiruv_tizimi_backend/utils/password_hasher.dart';
import 'package:dori_qidiruv_tizimi_backend/utils/response_helper.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    EnvConfig.init();
  });

  group('PasswordHasher', () {
    test('Hesh to‘g‘ri yaratilishi va tekshirilishi kerak', () {
      final rawPassword = 'superPassword123';
      final hash = PasswordHasher.hash(rawPassword);

      expect(hash, isNotEmpty);
      expect(hash, isNot(equals(rawPassword)));
      expect(PasswordHasher.verify(rawPassword, hash), isTrue);
      expect(PasswordHasher.verify('wrongPassword', hash), isFalse);
    });
  });

  group('AuthService JWT', () {
    test('JWT token to‘g‘ri yaratilishi va o‘qilishi kerak', () {
      final authService = AuthService();
      final token = authService.generateToken(
        userId: 1,
        email: 'admin@pharma.uz',
        role: 'admin',
        branchId: 10,
      );

      expect(token, isNotEmpty);

      final jwt = JWT.verify(token, SecretKey(EnvConfig.jwtSecret));
      final payload = jwt.payload as Map;

      expect(payload['sub'], equals(1));
      expect(payload['email'], equals('admin@pharma.uz'));
      expect(payload['role'], equals('admin'));
      expect(payload['branch_id'], equals(10));
    });
  });

  group('ResponseHelper', () {
    test('Muvaffaqiyatli JSON formati to‘g‘ri bo‘lishi kerak', () async {
      final response = ResponseHelper.success(
        data: {'item': 'Paratsetamol'},
        message: 'Topildi',
      );

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], contains('application/json'));

      final body = await response.readAsString();
      expect(body, contains('"success":true'));
      expect(body, contains('"item":"Paratsetamol"'));
      expect(body, contains('"message":"Topildi"'));
    });

    test('Xatolik JSON formati to‘g‘ri bo‘lishi kerak', () async {
      final response = ResponseHelper.badRequest('Yaroqsiz so‘rov');

      expect(response.statusCode, equals(400));
      final body = await response.readAsString();
      expect(body, contains('"success":false'));
      expect(body, contains('"status_code":400'));
      expect(body, contains('"error":"Yaroqsiz so‘rov"'));
    });
  });
}
