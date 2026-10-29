import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'middleware/auth_middleware.dart';
import 'middleware/cors_middleware.dart';
import 'modules/admin/admin_controller.dart';
import 'modules/auth/auth_controller.dart';
import 'modules/drugs/drugs_controller.dart';
import 'modules/favorites/favorites_controller.dart';
import 'modules/pharmacist/pharmacist_controller.dart';
import 'utils/response_helper.dart';

/// Serverning to'liq Shelf Pipeline va marshrutlarini qaytaruvchi funksiya.
/// Serverda ham, testlarda ham aynan bir xil pipeline ishlatiladi.
Handler createAppHandler() {
  final apiRouter = Router();

  // Health check
  apiRouter.get('/health', (Request request) {
    return ResponseHelper.success(
      data: {
        'status': 'online',
        'service': 'PharmaSearch Backend API',
        'timestamp': DateTime.now().toIso8601String(),
      },
      message: 'Server ishlamoqda',
    );
  });

  // Modullarni ulash (/api/v1/...)
  apiRouter.mount('/api/v1/auth', AuthController().router.call);
  apiRouter.mount('/api/v1/drugs', DrugsController().router.call);
  apiRouter.mount('/api/v1/favorites', FavoritesController().router.call);
  apiRouter.mount('/api/v1/pharmacist', PharmacistController().router.call);
  apiRouter.mount('/api/v1/admin', AdminController().router.call);

  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware)
      .addMiddleware(parseUserMiddleware)
      .addHandler(apiRouter.call);
}
