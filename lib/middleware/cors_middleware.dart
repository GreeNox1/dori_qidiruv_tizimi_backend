import 'package:shelf/shelf.dart';

/// Rock-solid CORS middleware that explicitly handles preflight (OPTIONS)
/// requests with 200 OK and attaches full CORS headers to all responses.
Middleware get corsMiddleware {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Authorization, Accept, X-Requested-With',
    'Access-Control-Max-Age': '86400',
  };

  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method.toUpperCase() == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      final response = await innerHandler(request);
      return response.change(headers: headers);
    };
  };
}
