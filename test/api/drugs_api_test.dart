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

  group('Drugs API Tests (/api/v1/drugs)', () {
    test('1. GET /search - Barcha dorilar ro‘yxatini sahifalash bilan qaytarishi kerak', () async {
      final res = await client.get('/api/v1/drugs/search?page=1&limit=3');

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data'], isList);
      expect((json['data'] as List).length, equals(3));
      expect(json['pagination']['current_page'], equals(1));
      expect(json['pagination']['limit'], equals(3));
      expect(json['pagination']['has_more'], isTrue);
    });

    test('2. GET /search?q=paratsetamol - Nom bo‘yicha qidiruv ishlashi kerak', () async {
      final res = await client.get('/api/v1/drugs/search?q=paratsetamol');

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      final List items = json['data'];
      expect(items, isNotEmpty);
      expect(items.any((item) => (item['trade_name'] as String).contains('PARATSETAMOL')), isTrue);
    });

    test('3. GET /search?district=Chilonzor - Tuman bo‘yicha filtr ishlashi kerak', () async {
      final res = await client.get('/api/v1/drugs/search?district=Chilonzor');

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data'], isNotEmpty);
    });

    test('4. GET /search - Tizimga kirgan foydalanuvchi uchun is_saved to‘g‘ri chiqishi kerak', () async {
      // 1. client@pharma.uz (userId=3) sevimlisida dori id=3 bor
      final loginRes = await client.post('/api/v1/auth/login', body: {
        'email': 'client@pharma.uz',
        'password': 'user12345',
      });
      final token = loginRes.json['data']['token'] as String;

      // 2. Qidiruvda tekshiramiz
      final res = await client.get('/api/v1/drugs/search', headers: {
        'Authorization': 'Bearer $token',
      });

      expect(res.statusCode, equals(200));
      final List items = res.json['data'];
      final kardiomagnil = items.firstWhere((i) => i['id'] == 3);
      expect(kardiomagnil['is_saved'], isTrue);

      final paratsetamol = items.firstWhere((i) => i['id'] == 1);
      expect(paratsetamol['is_saved'], isFalse);
    });

    test('5. GET /:id - Mavjud dori pasportini to‘liq qaytarishi kerak', () async {
      final res = await client.get('/api/v1/drugs/1');

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      final drug = json['data'];
      expect(drug['id'], equals(1));
      expect(drug['trade_name'], equals('PARATSETAMOL'));
      expect(drug['inn_name'], equals('Paracetamol'));
      expect(drug['indications'], isNotEmpty);
      expect(drug['dosage_instructions'], isNotEmpty);
      expect(drug['min_price'], equals(4200.0));
      expect(drug['pharmacy_count'], equals(3));
    });

    test('6. GET /:id - Mavjud bo‘lmagan dori ID uchun 404 qaytarishi kerak', () async {
      final res = await client.get('/api/v1/drugs/9999');

      expect(res.statusCode, equals(404));
      expect(res.json['success'], isFalse);
      expect(res.json['error'], contains('topilmadi'));
    });

    test('7. GET /:id/prices - Dorixonalar narxlar jadvalini qaytarishi kerak', () async {
      final res = await client.get('/api/v1/drugs/1/prices');

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      final List prices = json['data'];
      expect(prices, isNotEmpty);
      expect(prices.first['price'], equals(4200.0));
      expect(prices.first['branch']['pharmacy_name'], equals('Grand Pharm'));
      expect(prices.first['branch']['address'], isNotEmpty);
    });

    test('8. GET /:id/prices?district=Yunusobod - Narxlar jadvalida tuman filtri ishlashi kerak', () async {
      final res = await client.get('/api/v1/drugs/1/prices?district=Yunusobod');

      expect(res.statusCode, equals(200));
      final List prices = res.json['data'];
      expect(prices.length, equals(1));
      expect(prices.first['branch']['district'], equals('Yunusobod'));
      expect(prices.first['price'], equals(4500.0));
    });

    test('9. GET /:id/analogs - Faol moddasi bir xil bo‘lgan arzonroq analoglarni qaytarishi kerak', () async {
      final res = await client.get('/api/v1/drugs/1/analogs');

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      final List analogs = json['data'];
      expect(analogs, isNotEmpty);
      expect(analogs.first['trade_name'], equals('PARATSETAMOL EXTRA'));
      expect(analogs.first['inn_name'], equals('Paracetamol'));
    });
  });
}
