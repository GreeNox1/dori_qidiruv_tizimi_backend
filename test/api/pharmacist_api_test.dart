import 'package:dori_qidiruv_tizimi_backend/app.dart';
import 'package:dori_qidiruv_tizimi_backend/config/env_config.dart';
import 'package:test/test.dart';

import '../helpers/mock_db.dart';
import '../helpers/test_client.dart';

void main() {
  late TestClient client;
  late String pharmToken;
  late String userToken;

  setUpAll(() async {
    EnvConfig.init();
    client = TestClient(createAppHandler());
  });

  setUp(() async {
    MockDatabaseHelper.setupMockDatabase();

    // Pharmacist token
    final pRes = await client.post('/api/v1/auth/login', body: {
      'email': 'pharmacist@pharma.uz',
      'password': 'pharm12345',
    });
    pharmToken = pRes.json['data']['token'];

    // Regular user token
    final uRes = await client.post('/api/v1/auth/login', body: {
      'email': 'client@pharma.uz',
      'password': 'user12345',
    });
    userToken = uRes.json['data']['token'];
  });

  group('Pharmacist API Tests (/api/v1/pharmacist)', () {
    test('1. Oddiy mijoz (user) kirishga uringanda 403 Forbidden qaytarishi kerak', () async {
      final res = await client.get('/api/v1/pharmacist/branch', headers: {
        'Authorization': 'Bearer $userToken',
      });

      expect(res.statusCode, equals(403));
      expect(res.json['success'], isFalse);
    });

    test('2. GET /branch - Farmatsevt o‘z filial ma’lumotini olishi kerak', () async {
      final res = await client.get('/api/v1/pharmacist/branch', headers: {
        'Authorization': 'Bearer $pharmToken',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['name'], equals('Chilonzor filiali'));
      expect(json['data']['pharmacy_name'], equals('Grand Pharm'));
    });

    test('3. PUT /branch - Filial manzili va telefonini tahrirlash', () async {
      final res = await client.put('/api/v1/pharmacist/branch', body: {
        'address': 'Chilonzor 9-mavze, 12A-uy',
        'landmark': 'Rayhon milliy taomlari ro‘parasida',
        'phone': '+998 71 200-00-11',
        'working_hours': '08:00 - 23:30',
      }, headers: {
        'Authorization': 'Bearer $pharmToken',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['address'], equals('Chilonzor 9-mavze, 12A-uy'));
      expect(json['data']['phone'], equals('+998 71 200-00-11'));
    });

    test('4. GET /inventory - Filial omboridagi dorilar qoldiqlarini olish', () async {
      final res = await client.get('/api/v1/pharmacist/inventory', headers: {
        'Authorization': 'Bearer $pharmToken',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      final List items = json['data'];
      expect(items, isNotEmpty);
      expect(items.first['drug']['trade_name'], isNotEmpty);
    });

    test('5. POST /inventory - Filial omboriga katalogdagi dorini qo‘shish (201)', () async {
      final res = await client.post('/api/v1/pharmacist/inventory', body: {
        'drug_id': 4,
        'price': 6500.0,
        'quantity': 50,
      }, headers: {
        'Authorization': 'Bearer $pharmToken',
      });

      expect(res.statusCode, equals(201));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['drug_id'], equals(4));
      expect(json['data']['price'], equals(6500.0));
      expect(json['data']['quantity'], equals(50));
    });

    test('6. POST /inventory - Noto‘g‘ri narx kiritilganda 400 Bad Request qaytarishi kerak', () async {
      final res = await client.post('/api/v1/pharmacist/inventory', body: {
        'drug_id': 4,
        'price': -100.0,
        'quantity': 10,
      }, headers: {
        'Authorization': 'Bearer $pharmToken',
      });

      expect(res.statusCode, equals(400));
      expect(res.json['error'], contains('narx'));
    });

    test('7. PUT /inventory/:id - Mavjud dori narxi va qoldig‘ini yangilash', () async {
      // 1-yozuv: Chilonzor filiali, Paratsetamol
      final res = await client.put('/api/v1/pharmacist/inventory/1', body: {
        'price': 4600.0,
        'quantity': 35,
        'is_available': true,
      }, headers: {
        'Authorization': 'Bearer $pharmToken',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['price'], equals(4600.0));
      expect(json['data']['quantity'], equals(35));
    });

    test('8. DELETE /inventory/:id - Dorini ombordan chiqarish', () async {
      final res = await client.delete('/api/v1/pharmacist/inventory/1', headers: {
        'Authorization': 'Bearer $pharmToken',
      });

      expect(res.statusCode, equals(200));
      expect(res.json['success'], isTrue);
      expect(res.json['message'], contains('chiqarildi'));
    });
  });
}
