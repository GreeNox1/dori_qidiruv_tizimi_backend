import '../../config/database.dart';

class AdminService {
  Future<Map<String, dynamic>> getDashboardStats() async {
    final drugsRow = await Database.queryOne('SELECT COUNT(*) AS count FROM drugs;');
    final branchesRow = await Database.queryOne('SELECT COUNT(*) AS count FROM branches WHERE is_active = true;');
    final pharmRow = await Database.queryOne('''
      SELECT COUNT(*) AS count 
      FROM users u 
      JOIN roles r ON u.role_id = r.id 
      WHERE r.name = 'pharmacist';
    ''');
    final usersRow = await Database.queryOne('SELECT COUNT(*) AS count FROM users;');

    return {
      'total_drugs': int.tryParse(drugsRow?['count']?.toString() ?? '0') ?? 0,
      'active_branches': int.tryParse(branchesRow?['count']?.toString() ?? '0') ?? 0,
      'total_pharmacists': int.tryParse(pharmRow?['count']?.toString() ?? '0') ?? 0,
      'registered_users': int.tryParse(usersRow?['count']?.toString() ?? '0') ?? 0,
    };
  }

  Future<Map<String, dynamic>> createDrug(Map<String, dynamic> data) async {
    const sql = '''
      INSERT INTO drugs (
        trade_name, inn_name, form, dosage, manufacturer, 
        prescription_required, indications, dosage_instructions, 
        contraindications, storage_conditions, description
      )
      VALUES (
        @trade_name, @inn_name, @form, @dosage, @manufacturer,
        @prescription_required, @indications, @dosage_instructions,
        @contraindications, @storage_conditions, @description
      )
      RETURNING *;
    ''';

    final result = await Database.queryOne(sql, parameters: {
      'trade_name': data['trade_name']?.toString().trim(),
      'inn_name': data['inn_name']?.toString().trim(),
      'form': data['form']?.toString().trim(),
      'dosage': data['dosage']?.toString().trim(),
      'manufacturer': data['manufacturer']?.toString().trim(),
      'prescription_required': data['prescription_required'] == true,
      'indications': data['indications']?.toString(),
      'dosage_instructions': data['dosage_instructions']?.toString(),
      'contraindications': data['contraindications']?.toString(),
      'storage_conditions': data['storage_conditions']?.toString(),
      'description': data['description']?.toString(),
    });

    if (result == null) {
      throw const AdminException('Dorini yaratib bo‘lmadi', 500);
    }

    return result;
  }

  Future<Map<String, dynamic>> updateDrug(int id, Map<String, dynamic> data) async {
    const sql = '''
      UPDATE drugs
      SET trade_name = COALESCE(@trade_name, trade_name),
          inn_name = COALESCE(@inn_name, inn_name),
          form = COALESCE(@form, form),
          dosage = COALESCE(@dosage, dosage),
          manufacturer = COALESCE(@manufacturer, manufacturer),
          prescription_required = COALESCE(@prescription_required, prescription_required),
          indications = COALESCE(@indications, indications),
          dosage_instructions = COALESCE(@dosage_instructions, dosage_instructions),
          contraindications = COALESCE(@contraindications, contraindications),
          storage_conditions = COALESCE(@storage_conditions, storage_conditions),
          description = COALESCE(@description, description)
      WHERE id = @id
      RETURNING *;
    ''';

    final updated = await Database.queryOne(sql, parameters: {
      'id': id,
      'trade_name': data['trade_name']?.toString().trim(),
      'inn_name': data['inn_name']?.toString().trim(),
      'form': data['form']?.toString().trim(),
      'dosage': data['dosage']?.toString().trim(),
      'manufacturer': data['manufacturer']?.toString().trim(),
      'prescription_required': data.containsKey('prescription_required') ? data['prescription_required'] == true : null,
      'indications': data['indications']?.toString(),
      'dosage_instructions': data['dosage_instructions']?.toString(),
      'contraindications': data['contraindications']?.toString(),
      'storage_conditions': data['storage_conditions']?.toString(),
      'description': data['description']?.toString(),
    });

    if (updated == null) {
      throw const AdminException('Dori topilmadi yoki yangilab bo‘lmadi', 404);
    }

    return updated;
  }

  Future<void> deleteDrug(int id) async {
    // Check if drug exists in inventory
    const checkInvSql = 'SELECT COUNT(*) AS count FROM branch_inventory WHERE drug_id = @id;';
    final invRow = await Database.queryOne(checkInvSql, parameters: {'id': id});
    final invCount = int.tryParse(invRow?['count']?.toString() ?? '0') ?? 0;

    if (invCount > 0) {
      throw const AdminException(
        'Ushbu dori dorixona omborlariga kiritilgan. O‘chirishdan oldin inventardan chiqarilishi kerak',
        400,
      );
    }

    const sql = 'DELETE FROM drugs WHERE id = @id;';
    final affected = await Database.execute(sql, parameters: {'id': id});
    if (affected == 0) {
      throw const AdminException('Dori topilmadi', 404);
    }
  }

  Future<List<Map<String, dynamic>>> getBranches() async {
    const sql = '''
      SELECT b.*, p.name AS pharmacy_name,
             u.id AS pharmacist_id, u.full_name AS pharmacist_name, u.email AS pharmacist_email
      FROM branches b
      JOIN pharmacies p ON b.pharmacy_id = p.id
      LEFT JOIN branch_staff bs ON b.id = bs.branch_id
      LEFT JOIN users u ON bs.user_id = u.id
      ORDER BY b.id ASC;
    ''';

    return await Database.query(sql);
  }

  Future<Map<String, dynamic>> createBranch(Map<String, dynamic> data) async {
    const sql = '''
      INSERT INTO branches (
        pharmacy_id, name, district, address, landmark, phone, working_hours, is_active
      )
      VALUES (
        @pharmacy_id, @name, @district, @address, @landmark, @phone, @working_hours, @is_active
      )
      RETURNING *;
    ''';

    final pharmacyId = int.tryParse(data['pharmacy_id']?.toString() ?? '');
    if (pharmacyId == null) {
      throw const AdminException('pharmacy_id kiritilishi shart', 400);
    }

    final branch = await Database.queryOne(sql, parameters: {
      'pharmacy_id': pharmacyId,
      'name': data['name']?.toString().trim(),
      'district': data['district']?.toString().trim(),
      'address': data['address']?.toString().trim(),
      'landmark': data['landmark']?.toString().trim(),
      'phone': data['phone']?.toString().trim(),
      'working_hours': data['working_hours']?.toString().trim(),
      'is_active': data['is_active'] != false,
    });

    if (branch == null) {
      throw const AdminException('Filialni yaratib bo‘lmadi', 500);
    }

    final branchId = branch['id'] as int;

    // Optional assign pharmacist
    if (data['pharmacist_user_id'] != null) {
      final pharmacistId = int.tryParse(data['pharmacist_user_id'].toString());
      if (pharmacistId != null) {
        const staffSql = '''
          INSERT INTO branch_staff (user_id, branch_id)
          VALUES (@user_id, @branch_id)
          ON CONFLICT (user_id, branch_id) DO NOTHING;
        ''';
        await Database.execute(staffSql, parameters: {
          'user_id': pharmacistId,
          'branch_id': branchId,
        });
      }
    }

    return branch;
  }

  Future<Map<String, dynamic>> updateBranchStatus(int branchId, bool isActive) async {
    const sql = '''
      UPDATE branches
      SET is_active = @is_active
      WHERE id = @id
      RETURNING *;
    ''';

    final updated = await Database.queryOne(sql, parameters: {
      'id': branchId,
      'is_active': isActive,
    });

    if (updated == null) {
      throw const AdminException('Filial topilmadi', 404);
    }

    return updated;
  }
}

class AdminException implements Exception {
  final String message;
  final int statusCode;
  const AdminException(this.message, [this.statusCode = 400]);

  @override
  String toString() => message;
}
