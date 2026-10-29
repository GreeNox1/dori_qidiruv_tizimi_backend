import 'dart:async';
import 'package:postgres/postgres.dart';
import 'env_config.dart';
import 'in_memory_db.dart';

typedef QueryHandler = Future<List<Map<String, dynamic>>> Function(
  String sql,
  Map<String, dynamic>? parameters,
);

typedef ExecuteHandler = Future<int> Function(
  String sql,
  Map<String, dynamic>? parameters,
);

class Database {
  static Pool? _pool;
  static bool _fallbackToMemory = false;

  /// Testlar uchun mock handlerlar
  static QueryHandler? mockQueryHandler;
  static ExecuteHandler? mockExecuteHandler;

  static Pool get pool {
    if (_pool == null) {
      throw StateError(
          'Ma’lumotlar bazasi ulanishi initsializatsiya qilinmagan. Avval Database.init() chaqiring.');
    }
    return _pool!;
  }

  static void init() {
    if (_pool != null) return;

    final endpoint = Endpoint(
      host: EnvConfig.dbHost,
      port: EnvConfig.dbPort,
      database: EnvConfig.dbName,
      username: EnvConfig.dbUser,
      password: EnvConfig.dbPassword,
    );

    _pool = Pool.withEndpoints(
      [endpoint],
      settings: const PoolSettings(
        maxConnectionCount: 15,
        sslMode: SslMode.disable,
        connectTimeout: Duration(milliseconds: 500),
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> query(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    if (mockQueryHandler != null) {
      return await mockQueryHandler!(sql, parameters);
    }

    if (!_fallbackToMemory) {
      try {
        final result = await pool.execute(
          Sql.named(sql),
          parameters: parameters,
        ).timeout(const Duration(milliseconds: 500));
        return result.map((row) => row.toColumnMap()).toList();
      } catch (e) {
        _fallbackToMemory = true;
        print('⚠️ PostgreSQL ulanishi mavjud emas ($e). In-Memory bazaga o‘tildi.');
      }
    }

    return _handleMockQuery(sql, parameters);
  }

  static Future<Map<String, dynamic>?> queryOne(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    final rows = await query(sql, parameters: parameters);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<int> execute(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    if (mockExecuteHandler != null) {
      return await mockExecuteHandler!(sql, parameters);
    }

    if (!_fallbackToMemory) {
      try {
        final result = await pool.execute(
          Sql.named(sql),
          parameters: parameters,
        ).timeout(const Duration(milliseconds: 500));
        return result.affectedRows;
      } catch (e) {
        _fallbackToMemory = true;
        print('⚠️ PostgreSQL ulanishi mavjud emas ($e). In-Memory bazaga o‘tildi.');
      }
    }

    return _handleMockExecute(sql, parameters);
  }

  static Future<void> close() async {
    mockQueryHandler = null;
    mockExecuteHandler = null;
    if (_pool != null) {
      await _pool!.close();
      _pool = null;
    }
  }

  static List<Map<String, dynamic>> _handleMockQuery(
    String sql,
    Map<String, dynamic>? params,
  ) {
    final cleanSql = sql.replaceAll('\n', ' ').trim().toLowerCase();

    // 1. Roles
    if (cleanSql.contains('from roles')) {
      return InMemoryDb.roles;
    }

    // 2. User registration (INSERT INTO users ... RETURNING ...)
    if (cleanSql.contains('insert into users')) {
      final newId = InMemoryDb.users.length + 1;
      final roleId = params?['role_id'] as int? ?? 3;
      final newUser = <String, dynamic>{
        'id': newId,
        'full_name': params?['full_name']?.toString() ?? '',
        'email': params?['email']?.toString() ?? '',
        'password_hash': params?['password_hash']?.toString() ?? '',
        'phone': params?['phone']?.toString(),
        'role_id': roleId,
        'role': roleId == 1 ? 'admin' : (roleId == 2 ? 'pharmacist' : 'user'),
        'is_blocked': false,
        'created_at': DateTime.now().toIso8601String(),
        'branch_id': null,
      };
      InMemoryDb.users.add(newUser);
      return [newUser];
    }

    // 3. User by email
    if (cleanSql.contains('from users') && cleanSql.contains('lower(u.email)')) {
      final email = params?['email']?.toString().toLowerCase() ?? '';
      final user = InMemoryDb.users.cast<Map<String, dynamic>?>().firstWhere(
            (u) => u?['email']?.toString().toLowerCase() == email,
            orElse: () => null,
          );
      return user != null ? [Map<String, dynamic>.from(user)] : [];
    }

    // 4. User by ID
    if (cleanSql.contains('from users') && cleanSql.contains('u.id = @id')) {
      final id = params?['id'];
      final user = InMemoryDb.users.cast<Map<String, dynamic>?>().firstWhere(
            (u) => u?['id'] == id,
            orElse: () => null,
          );
      return user != null ? [Map<String, dynamic>.from(user)] : [];
    }

    // 5. Admin dashboard counts
    if (cleanSql.contains('count(*)') && cleanSql.contains('from drugs')) {
      return [{'count': InMemoryDb.drugs.length}];
    }
    if (cleanSql.contains('count(*)') && cleanSql.contains('from branches')) {
      return [{'count': InMemoryDb.branches.where((b) => b['is_active'] == true).length}];
    }
    if (cleanSql.contains('count(*)') && cleanSql.contains("r.name = 'pharmacist'")) {
      return [{'count': InMemoryDb.users.where((u) => u['role'] == 'pharmacist').length}];
    }
    if (cleanSql.contains('count(*)') && cleanSql.contains('from users')) {
      return [{'count': InMemoryDb.users.length}];
    }

    // 6. Saved drugs
    if (cleanSql.contains('insert into saved_drugs')) {
      final newId = InMemoryDb.savedDrugs.length + 1;
      final item = {
        'id': newId,
        'user_id': params?['user_id'],
        'drug_id': params?['drug_id'],
        'saved_at': DateTime.now().toIso8601String(),
      };
      InMemoryDb.savedDrugs.add(item);
      return [item];
    }

    if (cleanSql.contains('from saved_drugs') && cleanSql.contains('sd.user_id = @user_id')) {
      final userId = params?['user_id'];
      final userSaved = InMemoryDb.savedDrugs.where((s) => s['user_id'] == userId).toList();
      final result = <Map<String, dynamic>>[];
      for (final s in userSaved) {
        final drug = InMemoryDb.drugs.cast<Map<String, dynamic>?>().firstWhere(
              (d) => d?['id'] == s['drug_id'],
              orElse: () => null,
            );
        if (drug != null) {
          result.add({
            'saved_id': s['id'],
            'drug_id': s['drug_id'],
            'saved_at': s['saved_at'],
            'trade_name': drug['trade_name'],
            'inn_name': drug['inn_name'],
            'form': drug['form'],
            'dosage': drug['dosage'],
            'manufacturer': drug['manufacturer'],
            'min_price': drug['min_price'],
            'pharmacy_count': drug['pharmacy_count'] ?? 1,
          });
        }
      }
      return result;
    }

    if (cleanSql.contains('from saved_drugs') &&
        cleanSql.contains('user_id = @user_id') &&
        cleanSql.contains('drug_id = @drug_id')) {
      final userId = params?['user_id'];
      final drugId = params?['drug_id'];
      final item = InMemoryDb.savedDrugs.cast<Map<String, dynamic>?>().firstWhere(
            (s) => s?['user_id'] == userId && s?['drug_id'] == drugId,
            orElse: () => null,
          );
      return item != null ? [item] : [];
    }

    // 7. Drug prices
    if (cleanSql.contains('from branch_inventory') && cleanSql.contains('bi.drug_id = @drug_id')) {
      final drugId = params?['drug_id'];
      final district = params?['district']?.toString();
      var list = InMemoryDb.branchInventory.where((i) => i['drug_id'] == drugId && i['is_available'] == true).toList();
      if (district != null && district.isNotEmpty && district != 'Barchasi') {
        list = list.where((i) => i['district']?.toString().toLowerCase() == district.toLowerCase()).toList();
      }
      return list.map((item) {
        return {
          'id': item['id'],
          'branch_id': item['branch_id'],
          'price': item['price'],
          'quantity': item['quantity'],
          'is_available': item['is_available'],
          'updated_at': DateTime.now().toIso8601String(),
          'branch_name': item['branch_name'],
          'pharmacy_name': item['pharmacy_name'],
          'district': item['district'],
          'address': item['address'],
          'landmark': item['landmark'],
          'phone': item['phone'],
          'working_hours': item['working_hours'],
        };
      }).toList();
    }

    // 8. Drug detail by ID
    if (cleanSql.contains('from drugs') && cleanSql.contains('d.id = @id')) {
      final id = params?['id'];
      final drug = InMemoryDb.drugs.cast<Map<String, dynamic>?>().firstWhere(
            (d) => d?['id'] == id,
            orElse: () => null,
          );
      return drug != null ? [Map<String, dynamic>.from(drug)] : [];
    }

    // 9. Drug analogs
    if (cleanSql.contains('from drugs') && cleanSql.contains('d.id != @current_drug_id')) {
      final currentId = params?['current_drug_id'];
      final currentDrug = InMemoryDb.drugs.cast<Map<String, dynamic>?>().firstWhere(
            (d) => d?['id'] == currentId,
            orElse: () => null,
          );
      final inn = (currentDrug?['inn_name'] ?? '').toString().toLowerCase();
      final prefix = inn.split(' ').first;
      final analogs = InMemoryDb.drugs
          .where((d) => d['id'] != currentId && (d['inn_name']?.toString().toLowerCase().contains(prefix) ?? false))
          .take(6)
          .toList();
      return analogs.map((d) => Map<String, dynamic>.from(d)).toList();
    }

    // 10. Drug search total count
    if (cleanSql.contains('count(distinct d.id)')) {
      return [{'total': InMemoryDb.drugs.length}];
    }

    // 11. Drug search & list
    if (cleanSql.contains('from drugs')) {
      final q = params?['query']?.toString().toLowerCase() ?? params?['q']?.toString().toLowerCase() ?? '';
      var list = InMemoryDb.drugs.where((d) {
        if (q.isNotEmpty) {
          final t = d['trade_name']?.toString().toLowerCase() ?? '';
          final i = d['inn_name']?.toString().toLowerCase() ?? '';
          if (!t.contains(q) && !i.contains(q)) return false;
        }
        return true;
      }).toList();
      return list.map((d) => Map<String, dynamic>.from(d)).toList();
    }

    // 12. Pharmacist branch
    if (cleanSql.contains('from branch_staff')) {
      final userId = params?['user_id'];
      final user = InMemoryDb.users.cast<Map<String, dynamic>?>().firstWhere(
            (u) => u?['id'] == userId,
            orElse: () => null,
          );
      final branchId = user?['branch_id'] ?? 1;
      final branch = InMemoryDb.branches.cast<Map<String, dynamic>?>().firstWhere(
            (b) => b?['id'] == branchId,
            orElse: () => InMemoryDb.branches.first,
          );
      return branch != null ? [Map<String, dynamic>.from(branch)] : [];
    }

    // 13. Pharmacist inventory list
    if (cleanSql.contains('from branch_inventory bi') && cleanSql.contains('bi.branch_id = @branch_id')) {
      final branchId = params?['branch_id'];
      final q = params?['query']?.toString().toLowerCase() ?? '';
      var list = InMemoryDb.branchInventory.where((i) => i['branch_id'] == branchId).toList();
      if (q.isNotEmpty) {
        list = list.where((i) {
          final drug = InMemoryDb.drugs.cast<Map<String, dynamic>?>().firstWhere(
                (d) => d?['id'] == i['drug_id'],
                orElse: () => null,
              );
          final t = drug?['trade_name']?.toString().toLowerCase() ?? '';
          final inn = drug?['inn_name']?.toString().toLowerCase() ?? '';
          return t.contains(q) || inn.contains(q);
        }).toList();
      }
      return list.map((item) {
        final drug = InMemoryDb.drugs.cast<Map<String, dynamic>?>().firstWhere(
              (d) => d?['id'] == item['drug_id'],
              orElse: () => null,
            );
        return {
          'id': item['id'],
          'drug_id': item['drug_id'],
          'price': item['price'],
          'quantity': item['quantity'],
          'is_available': item['is_available'],
          'updated_at': DateTime.now().toIso8601String(),
          'trade_name': drug?['trade_name'] ?? 'Noma’lum',
          'inn_name': drug?['inn_name'] ?? '',
          'form': drug?['form'] ?? '',
          'dosage': drug?['dosage'] ?? '',
          'manufacturer': drug?['manufacturer'] ?? '',
        };
      }).toList();
    }

    // 14. Admin branches
    if (cleanSql.contains('from branches b')) {
      return InMemoryDb.branches.map((b) => Map<String, dynamic>.from(b)).toList();
    }

    // 15. Create drug (RETURNING *)
    if (cleanSql.contains('insert into drugs')) {
      final newId = InMemoryDb.drugs.length + 1;
      final newDrug = <String, dynamic>{
        'id': newId,
        'trade_name': params?['trade_name'],
        'inn_name': params?['inn_name'],
        'form': params?['form'],
        'dosage': params?['dosage'],
        'manufacturer': params?['manufacturer'],
        'prescription_required': params?['prescription_required'] == true,
        'indications': params?['indications'],
        'dosage_instructions': params?['dosage_instructions'],
        'contraindications': params?['contraindications'],
        'storage_conditions': params?['storage_conditions'],
        'description': params?['description'],
        'min_price': 5000.0,
        'max_price': 10000.0,
        'pharmacy_count': 0,
      };
      InMemoryDb.drugs.insert(0, newDrug);
      return [newDrug];
    }

    // 16. Create branch (RETURNING *)
    if (cleanSql.contains('insert into branches')) {
      final newId = InMemoryDb.branches.length + 1;
      final newBranch = <String, dynamic>{
        'id': newId,
        'pharmacy_id': params?['pharmacy_id'] ?? 1,
        'pharmacy_name': 'Grand Pharm',
        'name': params?['name'] ?? 'Yangi filial',
        'district': params?['district'] ?? 'Chilonzor',
        'address': params?['address'] ?? '',
        'landmark': params?['landmark'],
        'phone': params?['phone'] ?? '',
        'working_hours': params?['working_hours'] ?? '08:00 - 22:00',
        'is_active': true,
      };
      InMemoryDb.branches.add(newBranch);
      return [newBranch];
    }

    return [];
  }

  static int _handleMockExecute(String sql, Map<String, dynamic>? params) {
    final cleanSql = sql.replaceAll('\n', ' ').trim().toLowerCase();

    // Delete saved drug
    if (cleanSql.contains('delete from saved_drugs')) {
      final id = params?['id'];
      InMemoryDb.savedDrugs.removeWhere((s) => s['id'] == id);
      return 1;
    }

    // Delete drug
    if (cleanSql.contains('delete from drugs')) {
      final id = params?['id'];
      InMemoryDb.drugs.removeWhere((d) => d['id'] == id);
      InMemoryDb.branchInventory.removeWhere((i) => i['drug_id'] == id);
      return 1;
    }

    // Delete inventory item
    if (cleanSql.contains('delete from branch_inventory')) {
      final id = params?['id'];
      InMemoryDb.branchInventory.removeWhere((i) => i['id'] == id);
      return 1;
    }

    // Update branch inventory
    if (cleanSql.contains('update branch_inventory')) {
      final id = params?['id'];
      final item = InMemoryDb.branchInventory.cast<Map<String, dynamic>?>().firstWhere(
            (i) => i?['id'] == id,
            orElse: () => null,
          );
      if (item != null) {
        if (params?['price'] != null) item['price'] = params!['price'];
        if (params?['quantity'] != null) item['quantity'] = params!['quantity'];
        if (params?['is_available'] != null) item['is_available'] = params!['is_available'];
        return 1;
      }
      return 0;
    }

    // Update branches
    if (cleanSql.contains('update branches')) {
      final id = params?['branch_id'] ?? params?['id'];
      final b = InMemoryDb.branches.cast<Map<String, dynamic>?>().firstWhere(
            (b) => b?['id'] == id,
            orElse: () => null,
          );
      if (b != null) {
        if (params?['address'] != null) b['address'] = params!['address'];
        if (params?['landmark'] != null) b['landmark'] = params!['landmark'];
        if (params?['phone'] != null) b['phone'] = params!['phone'];
        if (params?['working_hours'] != null) b['working_hours'] = params!['working_hours'];
        if (params?['is_active'] != null) b['is_active'] = params!['is_active'];
        return 1;
      }
      return 0;
    }

    return 1;
  }
}