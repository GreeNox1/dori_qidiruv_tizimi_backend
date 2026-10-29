import 'package:dori_qidiruv_tizimi_backend/app.dart';
import 'package:dori_qidiruv_tizimi_backend/config/env_config.dart';
import 'package:test/test.dart';

import '../helpers/mock_db.dart';
import '../helpers/test_client.dart';

void main() {
  late TestClient client;

  setUpAll(() {
    EnvConfig.init();
    client = TestClient(createAppHandler());
  });

  setUp(() {
    MockDatabaseHelper.setupMockDatabase();
  });

  group('Auth API Tests (/api/v1/auth)', () {
    test('1. POST /login - Admin muvaffaqiyatli kirishi kerak', () async {
      final res = await client.post('/api/v1/auth/login', body: {
        'email': 'admin@pharma.uz',
        'password': 'admin12345',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['token'], isNotEmpty);
      expect(json['data']['user']['email'], equals('admin@pharma.uz'));
      expect(json['data']['user']['role'], equals('admin'));
    });

    test('2. POST /login - Farmatsevt kirishi va branch_id qaytishi kerak', () async {
      final res = await client.post('/api/v1/auth/login', body: {
        'email': 'pharmacist@pharma.uz',
        'password': 'pharm12345',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['user']['role'], equals('pharmacist'));
      expect(json['data']['user']['branch_id'], equals(1));
    });

    test('3. POST /login - Noto‘g‘ri parol kiritilganda 401 qaytarishi kerak', () async {
      final res = await client.post('/api/v1/auth/login', body: {
        'email': 'admin@pharma.uz',
        'password': 'noto‘g‘riParol',
      });

      expect(res.statusCode, equals(401));
      final json = res.json;
      expect(json['success'], isFalse);
      expect(json['error'], contains('Email yoki parol noto‘g‘ri'));
    });

    test('4. POST /login - Bloklangan foydalanuvchi kirishga uringanda 403 qaytarishi kerak', () async {
      final res = await client.post('/api/v1/auth/login', body: {
        'email': 'blocked@pharma.uz',
        'password': 'user12345',
      });

      expect(res.statusCode, equals(403));
      final json = res.json;
      expect(json['success'], isFalse);
      expect(json['error'], contains('bloklangan'));
    });

    test('5. POST /register - Yangi mijoz muvaffaqiyatli ro‘yxatdan o‘tishi kerak (201)', () async {
      final res = await client.post('/api/v1/auth/register', body: {
        'full_name': 'Botir Qodirov',
        'email': 'botir@test.uz',
        'password': 'password123',
        'phone': '+998 90 999 88 77',
      });

      expect(res.statusCode, equals(201));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['token'], isNotEmpty);
      expect(json['data']['user']['full_name'], equals('Botir Qodirov'));
      expect(json['data']['user']['role'], equals('user'));
    });

    test('6. POST /register - Mavjud email bilan ro‘yxatdan o‘tishda 409 Conflict qaytarishi kerak', () async {
      final res = await client.post('/api/v1/auth/register', body: {
        'full_name': 'Boshqa Ism',
        'email': 'admin@pharma.uz',
        'password': 'password123',
      });

      expect(res.statusCode, equals(409));
      expect(res.json['success'], isFalse);
      expect(res.json['error'], contains('allaqachon ro‘yxatdan o‘tgan'));
    });

    test('7. POST /register - Qisqa parol kiritilganda (<6) 400 Bad Request qaytarishi kerak', () async {
      final res = await client.post('/api/v1/auth/register', body: {
        'full_name': 'Test User',
        'email': 'valid@mail.uz',
        'password': '123',
      });

      expect(res.statusCode, equals(400));
      expect(res.json['error'], contains('kamida 6 ta'));
    });

    test('8. GET /me - To‘g‘ri Bearer token bilan profil ma’lumotini qaytarishi kerak', () async {
      // 1. Login qilib token olamiz
      final loginRes = await client.post('/api/v1/auth/login', body: {
        'email': 'client@pharma.uz',
        'password': 'user12345',
      });
      final token = loginRes.json['data']['token'] as String;

      // 2. /me ga so'rov yuboramiz
      final meRes = await client.get('/api/v1/auth/me', headers: {
        'Authorization': 'Bearer $token',
      });

      expect(meRes.statusCode, equals(200));
      final json = meRes.json;
      expect(json['success'], isTrue);
      expect(json['data']['email'], equals('client@pharma.uz'));
      expect(json['data']['role'], equals('user'));
    });

    test('9. GET /me - Tokensiz murojaat qilinganda 401 Unauthorized qaytarishi kerak', () async {
      final res = await client.get('/api/v1/auth/me');
      expect(res.statusCode, equals(401));
      expect(res.json['success'], isFalse);
    });
  });
}
