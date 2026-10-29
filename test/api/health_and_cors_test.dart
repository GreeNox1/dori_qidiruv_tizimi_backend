import 'package:dori_qidiruv_tizimi_backend/app.dart';
import 'package:dori_qidiruv_tizimi_backend/config/env_config.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../helpers/test_client.dart';

void main() {
  late TestClient client;
  late Handler handler;

  setUpAll(() {
    EnvConfig.init();
    handler = createAppHandler();
    client = TestClient(handler);
  });

  group('Health & CORS Tests', () {
    test('1. GET /health - Server holatini 200 OK bilan qaytarishi kerak', () async {
      final res = await client.get('/health');

      expect(res.statusCode, equals(200));
      final json = res.json;
      expect(json['success'], isTrue);
      expect(json['data']['status'], equals('online'));
      expect(json['data']['service'], contains('PharmaSearch'));
      expect(json['message'], equals('Server ishlamoqda'));
    });

    test('2. CORS - Har bir javobda Access-Control-Allow-* sarlavhalari bo‘lishi kerak', () async {
      final res = await client.get('/health', headers: {
        'Origin': 'http://localhost:3000',
      });

      expect(res.statusCode, equals(200));
      expect(res.headers['access-control-allow-origin'], isNotNull);
      expect(res.headers['access-control-allow-origin'], equals('*'));
    });

    test('3. OPTIONS pre-flight so‘rovi to‘g‘ri javob berishi kerak', () async {
      final request = Request('OPTIONS', Uri.parse('http://localhost:8080/api/v1/auth/login'), headers: {
        'Origin': 'http://localhost:3000',
        'Access-Control-Request-Method': 'POST',
      });

      final response = await handler(request);
      expect(response.statusCode, equals(200));
      expect(response.headers['access-control-allow-origin'], equals('*'));
      expect(response.headers['access-control-allow-methods'], contains('POST'));
    });
  });
}
