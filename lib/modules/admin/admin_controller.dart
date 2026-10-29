import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../middleware/auth_middleware.dart';
import '../../middleware/role_guard.dart';
import '../../utils/response_helper.dart';
import 'admin_service.dart';

class AdminController {
  final AdminService _service = AdminService();

  Router get router {
    final router = Router();

    final protectedRouter = Router();
    protectedRouter.get('/dashboard', _getDashboard);

    // Drugs CRUD
    protectedRouter.post('/drugs', _createDrug);
    protectedRouter.put('/drugs/<id|[0-9]+>', _updateDrug);
    protectedRouter.delete('/drugs/<id|[0-9]+>', _deleteDrug);

    // Branches
    protectedRouter.get('/branches', _getBranches);
    protectedRouter.post('/branches', _createBranch);
    protectedRouter.patch('/branches/<id|[0-9]+>/status', _updateBranchStatus);

    final handler = const Pipeline()
        .addMiddleware(requireAuthMiddleware)
        .addMiddleware(adminOnlyGuard)
        .addHandler(protectedRouter.call);

    router.mount('/', handler);

    return router;
  }

  Future<Response> _getDashboard(Request request) async {
    try {
      final stats = await _service.getDashboardStats();
      return ResponseHelper.success(data: stats);
    } catch (e) {
      return ResponseHelper.internalServerError('Dashboard ma’lumotlarini olishda xatolik: $e');
    }
  }

  Future<Response> _createDrug(Request request) async {
    try {
      final bodyStr = await request.readAsString();
      if (bodyStr.trim().isEmpty) {
        return ResponseHelper.badRequest('So‘rov tanasi bo‘sh bo‘lishi mumkin emas');
      }

      final body = jsonDecode(bodyStr);
      if (body is! Map<String, dynamic>) {
        return ResponseHelper.badRequest('Yaroqsiz JSON formati');
      }

      final tradeName = body['trade_name']?.toString().trim() ?? '';
      final innName = body['inn_name']?.toString().trim() ?? '';
      final form = body['form']?.toString().trim() ?? '';

      if (tradeName.isEmpty || innName.isEmpty || form.isEmpty) {
        return ResponseHelper.badRequest('trade_name, inn_name va form maydonlari kiritilishi shart');
      }

      final drug = await _service.createDrug(body);
      return ResponseHelper.success(
        data: drug,
        message: 'Dori katalogga muvaffaqiyatli qo‘shildi',
        statusCode: 201,
      );
    } on AdminException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Dorini qo‘shishda xatolik: $e');
    }
  }

  Future<Response> _updateDrug(Request request, String id) async {
    try {
      final drugId = int.tryParse(id);
      if (drugId == null) {
        return ResponseHelper.badRequest('Yaroqsiz dori identifikatori');
      }

      final bodyStr = await request.readAsString();
      if (bodyStr.trim().isEmpty) {
        return ResponseHelper.badRequest('So‘rov tanasi bo‘sh bo‘lishi mumkin emas');
      }

      final body = jsonDecode(bodyStr);
      if (body is! Map<String, dynamic>) {
        return ResponseHelper.badRequest('Yaroqsiz JSON formati');
      }

      final updated = await _service.updateDrug(drugId, body);
      return ResponseHelper.success(
        data: updated,
        message: 'Dori muvaffaqiyatli tahrirlandi',
      );
    } on AdminException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Dorini tahrirlashda xatolik: $e');
    }
  }

  Future<Response> _deleteDrug(Request request, String id) async {
    try {
      final drugId = int.tryParse(id);
      if (drugId == null) {
        return ResponseHelper.badRequest('Yaroqsiz dori identifikatori');
      }

      await _service.deleteDrug(drugId);
      return ResponseHelper.success(message: 'Dori katalogdan o‘chirildi');
    } on AdminException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Dorini o‘chirishda xatolik: $e');
    }
  }

  Future<Response> _getBranches(Request request) async {
    try {
      final branches = await _service.getBranches();
      return ResponseHelper.success(data: branches);
    } catch (e) {
      return ResponseHelper.internalServerError('Filiallar ro‘yxatini olishda xatolik: $e');
    }
  }

  Future<Response> _createBranch(Request request) async {
    try {
      final bodyStr = await request.readAsString();
      if (bodyStr.trim().isEmpty) {
        return ResponseHelper.badRequest('So‘rov tanasi bo‘sh bo‘lishi mumkin emas');
      }

      final body = jsonDecode(bodyStr);
      if (body is! Map<String, dynamic>) {
        return ResponseHelper.badRequest('Yaroqsiz JSON formati');
      }

      final name = body['name']?.toString().trim() ?? '';
      final district = body['district']?.toString().trim() ?? '';
      final address = body['address']?.toString().trim() ?? '';
      final phone = body['phone']?.toString().trim() ?? '';
      final workingHours = body['working_hours']?.toString().trim() ?? '';

      if (name.isEmpty || district.isEmpty || address.isEmpty || phone.isEmpty || workingHours.isEmpty) {
        return ResponseHelper.badRequest('name, district, address, phone va working_hours kiritilishi shart');
      }

      final branch = await _service.createBranch(body);
      return ResponseHelper.success(
        data: branch,
        message: 'Filial muvaffaqiyatli yaratildi',
        statusCode: 201,
      );
    } on AdminException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Filial yaratishda xatolik: $e');
    }
  }

  Future<Response> _updateBranchStatus(Request request, String id) async {
    try {
      final branchId = int.tryParse(id);
      if (branchId == null) {
        return ResponseHelper.badRequest('Yaroqsiz filial identifikatori');
      }

      final bodyStr = await request.readAsString();
      if (bodyStr.trim().isEmpty) {
        return ResponseHelper.badRequest('So‘rov tanasi bo‘sh bo‘lishi mumkin emas');
      }

      final body = jsonDecode(bodyStr);
      if (body is! Map<String, dynamic> || !body.containsKey('is_active')) {
        return ResponseHelper.badRequest('is_active maydoni kiritilishi shart (true yoki false)');
      }

      final isActive = body['is_active'] == true;
      final updated = await _service.updateBranchStatus(branchId, isActive);

      return ResponseHelper.success(
        data: updated,
        message: 'Filial holati muvaffaqiyatli yangilandi',
      );
    } on AdminException catch (e) {
      return ResponseHelper.error(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      return ResponseHelper.internalServerError('Filial holatini yangilashda xatolik: $e');
    }
  }
}
