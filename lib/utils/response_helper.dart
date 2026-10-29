import 'dart:convert';
import 'package:shelf/shelf.dart';

class ResponseHelper {
  static const Map<String, String> _headers = {
    'content-type': 'application/json; charset=utf-8',
  };

  static Response success({
    dynamic data,
    String? message,
    int statusCode = 200,
    Map<String, dynamic>? pagination,
    Map<String, dynamic>? extra,
  }) {
    final Map<String, dynamic> body = {
      'success': true,
      'data': data,
      'message': ?message,
      'pagination': ?pagination,
      ...?extra,
    };

    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: _headers,
    );
  }

  static Response error({
    required String message,
    int statusCode = 400,
    dynamic data,
  }) {
    final body = {
      'success': false,
      'data': data,
      'error': message,
      'status_code': statusCode,
    };

    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: _headers,
    );
  }

  static Response badRequest(String message) =>
      error(message: message, statusCode: 400);

  static Response unauthorized([String message = 'Autentifikatsiyadan o‘tilmagan']) =>
      error(message: message, statusCode: 401);

  static Response forbidden([String message = 'Ruxsat berilmagan']) =>
      error(message: message, statusCode: 403);

  static Response notFound([String message = 'Ma’lumot topilmadi']) =>
      error(message: message, statusCode: 404);

  static Response conflict(String message) =>
      error(message: message, statusCode: 409);

  static Response internalServerError([String message = 'Serverda ichki xatolik yuz berdi']) =>
      error(message: message, statusCode: 500);
}
