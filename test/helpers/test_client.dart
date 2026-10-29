import 'dart:convert';
import 'package:shelf/shelf.dart';

class TestClient {
  final Handler handler;
  TestClient(this.handler);

  Future<TestResponse> get(String path, {Map<String, String>? headers}) async {
    final request = Request('GET', Uri.parse('http://localhost:8080$path'), headers: headers);
    final response = await handler(request);
    return TestResponse(response, await response.readAsString());
  }

  Future<TestResponse> post(String path, {dynamic body, Map<String, String>? headers}) async {
    final bodyStr = body == null ? '' : (body is String ? body : jsonEncode(body));
    final h = {'content-type': 'application/json', ...?headers};
    final request = Request('POST', Uri.parse('http://localhost:8080$path'), body: bodyStr, headers: h);
    final response = await handler(request);
    return TestResponse(response, await response.readAsString());
  }

  Future<TestResponse> put(String path, {dynamic body, Map<String, String>? headers}) async {
    final bodyStr = body == null ? '' : (body is String ? body : jsonEncode(body));
    final h = {'content-type': 'application/json', ...?headers};
    final request = Request('PUT', Uri.parse('http://localhost:8080$path'), body: bodyStr, headers: h);
    final response = await handler(request);
    return TestResponse(response, await response.readAsString());
  }

  Future<TestResponse> patch(String path, {dynamic body, Map<String, String>? headers}) async {
    final bodyStr = body == null ? '' : (body is String ? body : jsonEncode(body));
    final h = {'content-type': 'application/json', ...?headers};
    final request = Request('PATCH', Uri.parse('http://localhost:8080$path'), body: bodyStr, headers: h);
    final response = await handler(request);
    return TestResponse(response, await response.readAsString());
  }

  Future<TestResponse> delete(String path, {Map<String, String>? headers}) async {
    final request = Request('DELETE', Uri.parse('http://localhost:8080$path'), headers: headers);
    final response = await handler(request);
    return TestResponse(response, await response.readAsString());
  }
}

class TestResponse {
  final Response raw;
  final String bodyString;
  TestResponse(this.raw, this.bodyString);

  int get statusCode => raw.statusCode;
  Map<String, String> get headers => raw.headers;
  dynamic get json => jsonDecode(bodyString);
}
