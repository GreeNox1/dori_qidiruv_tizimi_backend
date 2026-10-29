import 'package:dori_qidiruv_tizimi_backend/app.dart';
import 'package:dori_qidiruv_tizimi_backend/config/env_config.dart';
import 'package:test/test.dart';

import '../helpers/mock_db.dart';
import '../helpers/test_client.dart';

void main() {
  late TestClient client;
  late String adminToken;
  late String pharmToken;

  setUpAll(() async {
    EnvConfig.init();
    client = TestClient(createAppHandler());
  });

  setUp(() async {
    MockDatabaseHelper.setupMockDatabase();

    // Admin token
    final aRes = await client.post('/api/v1/auth/login', body: {
      'email': 'admin@pharma.uz',
      'password': 'admin12345',
    });
    adminToken = aRes.json['data']['token'];

    // Pharmacist token
    final pRes = await client.post('/api/v1/auth/login', body: {
      'email': 'pharmacist@pharma.uz',
      'password': 'pharm12345',
    });
    pharmToken = pRes.json['data']['token'];
  });

  group('Admin API Tests (/api/v1/admin)', () {
    test('1. Farmatsevt admin endpointiga kirishga uringanda 403 Forbidden qaytarishi kerak', () async {
      final res = await client.get('/api/v1/admin/dashboard', headers: {
        'Authorization': 'Bearer $pharmToken',
      });

      expect(res.statusCode, equals(403));
      expect(res.json['success'], isFalse);
    });

    test('2. GET /dashboard - Admin tizim statistikasini olishi kerak (200)', () async {
      final res = await client.get('/api/v1/admin/dashboard', headers: {
        'Authorization': 'Bearer $adminToken',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['total_drugs'], greaterThan(0));
      expect(json['data']['active_branches'], greaterThan(0));
      expect(json['data']['total_pharmacists'], greaterThan(0));
      expect(json['data']['registered_users'], greaterThan(0));
    });

    test('3. POST /drugs - Katalogga yangi dori qo‘shish (201)', () async {
      final res = await client.post('/api/v1/admin/drugs', body: {
        'trade_name': 'TRIMEDAT',
        'inn_name': 'Trimebutine',
        'form': 'Tabletka',
        'dosage': '200 mg',
        'manufacturer': 'Dae Han, Koreya',
        'prescription_required': false,
        'indications': 'Oshqozon motorikasi',
      }, headers: {
        'Authorization': 'Bearer $adminToken',
      });

      expect(res.statusCode, equals(201));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['trade_name'], equals('TRIMEDAT'));
      expect(json['data']['inn_name'], equals('Trimebutine'));
    });

    test('4. POST /drugs - Majburiy maydonlar bo‘sh bo‘lganda 400 Bad Request qaytarishi kerak', () async {
      final res = await client.post('/api/v1/admin/drugs', body: {
        'trade_name': '',
        'inn_name': '',
      }, headers: {
        'Authorization': 'Bearer $adminToken',
      });

      expect(res.statusCode, equals(400));
      expect(res.json['error'], contains('kiritilishi shart'));
    });

    test('5. PUT /drugs/:id - Mavjud dorini tahrirlash', () async {
      final res = await client.put('/api/v1/admin/drugs/1', body: {
        'dosage': '1000 mg',
        'storage_conditions': '30°C gacha',
      }, headers: {
        'Authorization': 'Bearer $adminToken',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['dosage'], equals('1000 mg'));
      expect(json['data']['storage_conditions'], equals('30°C gacha'));
    });

    test('6. DELETE /drugs/:id - Omborlarda mavjud dori o‘chirilmasligi va 400 qaytarishi kerak', () async {
      // 1-dori filial omborlarida bor
      final res = await client.delete('/api/v1/admin/drugs/1', headers: {
        'Authorization': 'Bearer $adminToken',
      });

      expect(res.statusCode, equals(400));
      expect(res.json['error'], contains('omborlariga kiritilgan'));
    });

    test('7. GET /branches - Filiallar ro‘yxati va biriktirilgan farmatsevtlar chiqishi kerak', () async {
      final res = await client.get('/api/v1/admin/branches', headers: {
        'Authorization': 'Bearer $adminToken',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      final List branches = json['data'];
      expect(branches, isNotEmpty);
      expect(branches.first['pharmacy_name'], equals('Grand Pharm'));
      expect(branches.first['pharmacist_name'], equals('Sardor Aliyev (Farmatsevt)'));
    });

    test('8. POST /branches - Yangi filial yaratish (201)', () async {
      final res = await client.post('/api/v1/admin/branches', body: {
        'pharmacy_id': 1,
        'name': 'Yakkasaroy filiali',
        'district': 'Yakkasaroy',
        'address': 'Shota Rustaveli ko‘chasi, 15',
        'landmark': 'Grand Mir mehmonxonasi',
        'phone': '+998 71 200-00-55',
        'working_hours': '09:00 - 22:00',
        'pharmacist_user_id': 2,
      }, headers: {
        'Authorization': 'Bearer $adminToken',
      });

      expect(res.statusCode, equals(201));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['name'], equals('Yakkasaroy filiali'));
      expect(json['data']['district'], equals('Yakkasaroy'));
    });

    test('9. PATCH /branches/:id/status - Filial faollik holatini o‘zgartirish (true -> false)', () async {
      final res = await client.patch('/api/v1/admin/branches/1/status', body: {
        'is_active': false,
      }, headers: {
        'Authorization': 'Bearer $adminToken',
      });

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['is_active'], isFalse);
    });
  });
}
