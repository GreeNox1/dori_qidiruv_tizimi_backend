import 'package:dori_qidiruv_tizimi_backend/app.dart';
import 'package:dori_qidiruv_tizimi_backend/config/env_config.dart';
import 'package:test/test.dart';

import '../helpers/mock_db.dart';
import '../helpers/test_client.dart';

void main() {
  late TestClient client;
  late String userToken;

  setUpAll(() async {
    EnvConfig.init();
    client = TestClient(createAppHandler());
  });

  setUp(() async {
    MockDatabaseHelper.setupMockDatabase();
    // Login to get token for client@pharma.uz (id=3)
    final res = await client.post('/api/v1/auth/login', body: {
      'email': 'client@pharma.uz',
      'password': 'user12345',
    });
    userToken = res.json['data']['token'];
  });

  group('Favorites API Tests (/api/v1/favorites)', () {
    test('1. GET / - Tizimga kirgan foydalanuvchining sevimlilar ro‘yxatini qaytarishi kerak', () async {
      final res = await client.get('/api/v1/favorites', headers: {
        'Authorization': 'Bearer $userToken',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      final List data = json['data'];
      expect(data, isNotEmpty);
      expect(data.first['drug']['trade_name'], equals('KARDIOMAGNIL'));
    });

    test('2. GET / - Tokensiz murojaat qilinganda 401 Unauthorized qaytarishi kerak', () async {
      final res = await client.get('/api/v1/favorites');
      expect(res.statusCode, equals(401));
      expect(res.json['success'], isFalse);
    });

    test('3. POST /toggle - Yangi dorini sevimlilarga qo‘shish (is_saved: true)', () async {
      final res = await client.post('/api/v1/favorites/toggle', body: {
        'drug_id': 1,
      }, headers: {
        'Authorization': 'Bearer $userToken',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['is_saved'], isTrue);
      expect(json['message'], contains('saqlandi'));
    });

    test('4. POST /toggle - Avval saqlangan dorini sevimlilardan o‘chirish (is_saved: false)', () async {
      // 3-dori avvaldan saqlangan
      final res = await client.post('/api/v1/favorites/toggle', body: {
        'drug_id': 3,
      }, headers: {
        'Authorization': 'Bearer $userToken',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['is_saved'], isFalse);
      expect(json['message'], contains('o‘chirildi'));
    });

    test('5. POST /toggle - Mavjud bo‘lmagan drug_id uchun 404 qaytarishi kerak', () async {
      final res = await client.post('/api/v1/favorites/toggle', body: {
        'drug_id': 9999,
      }, headers: {
        'Authorization': 'Bearer $userToken',
      });

      expect(res.statusCode, equals(404));
      expect(res.json['success'], isFalse);
      expect(res.json['error'], contains('topilmadi'));
    });

    test('6. POST /toggle - drug_id uzatilmaganda 400 Bad Request qaytarishi kerak', () async {
      final res = await client.post('/api/v1/favorites/toggle', body: {}, headers: {
        'Authorization': 'Bearer $userToken',
      });

      expect(res.statusCode, equals(400));
      expect(res.json['error'], contains('drug_id'));
    });
  });
}
