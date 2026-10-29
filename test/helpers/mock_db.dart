import 'package:dori_qidiruv_tizimi_backend/config/database.dart';
import 'package:dori_qidiruv_tizimi_backend/utils/password_hasher.dart';

class MockDatabaseHelper {
  static List<Map<String, dynamic>> users = [];
  static List<Map<String, dynamic>> roles = [];
  static List<Map<String, dynamic>> pharmacies = [];
  static List<Map<String, dynamic>> branches = [];
  static List<Map<String, dynamic>> branchStaff = [];
  static List<Map<String, dynamic>> drugs = [];
  static List<Map<String, dynamic>> branchInventory = [];
  static List<Map<String, dynamic>> savedDrugs = [];

  static int _nextUserId = 100;
  static int _nextDrugId = 100;
  static int _nextBranchId = 100;
  static int _nextInventoryId = 100;
  static int _nextSavedDrugId = 100;

  static void setupMockDatabase() {
    reset();

    Database.mockQueryHandler = (String sql, Map<String, dynamic>? parameters) async {
      final s = sql.replaceAll(RegExp(r'\s+'), ' ').trim();
      final p = parameters ?? {};

      // 1. AUTH: find user by email
      if (s.contains('FROM users u') && s.contains('LOWER(u.email) = LOWER(@email)')) {
        final email = (p['email'] as String?)?.toLowerCase();
        for (final u in users) {
          if ((u['email'] as String).toLowerCase() == email) {
            final role = roles.firstWhere((r) => r['id'] == u['role_id'])['name'];
            final staff = branchStaff.where((bs) => bs['user_id'] == u['id']).firstOrNull;
            return [
              {
                'id': u['id'],
                'full_name': u['full_name'],
                'email': u['email'],
                'password_hash': u['password_hash'],
                'phone': u['phone'],
                'is_blocked': u['is_blocked'] ?? false,
                'role': role,
                'branch_id': staff?['branch_id'],
              }
            ];
          }
        }
        return [];
      }

      // 2. AUTH: find user by id
      if (s.contains('FROM users u') && s.contains('WHERE u.id = @id')) {
        final id = p['id'] as int?;
        for (final u in users) {
          if (u['id'] == id) {
            final role = roles.firstWhere((r) => r['id'] == u['role_id'])['name'];
            final staff = branchStaff.where((bs) => bs['user_id'] == u['id']).firstOrNull;
            return [
              {
                'id': u['id'],
                'full_name': u['full_name'],
                'email': u['email'],
                'phone': u['phone'],
                'is_blocked': u['is_blocked'] ?? false,
                'role': role,
                'branch_id': staff?['branch_id'],
                'created_at': u['created_at'],
              }
            ];
          }
        }
        return [];
      }

      // 3. AUTH: role id for 'user'
      if (s.contains("SELECT id FROM roles WHERE name = 'user'")) {
        return [{'id': 3}];
      }

      // 4. AUTH: insert user
      if (s.contains('INSERT INTO users')) {
        final newId = ++_nextUserId;
        final newUser = {
          'id': newId,
          'full_name': p['full_name'],
          'email': p['email'],
          'password_hash': p['password_hash'],
          'phone': p['phone'],
          'role_id': p['role_id'],
          'is_blocked': false,
          'created_at': DateTime.now().toIso8601String(),
        };
        users.add(newUser);
        return [
          {
            'id': newId,
            'full_name': newUser['full_name'],
            'email': newUser['email'],
            'phone': newUser['phone'],
            'role_id': newUser['role_id'],
            'created_at': newUser['created_at'],
          }
        ];
      }

      // 5. DRUGS: Search drugs
      if (s.contains('FROM drugs d') && s.contains('GROUP BY d.id') && s.contains('LIMIT @limit OFFSET @offset')) {
        final q = p['q'] as String?;
        final district = p['district'] as String?;
        final inStock = p['in_stock'] == true;
        final limit = p['limit'] as int? ?? 10;
        final offset = p['offset'] as int? ?? 0;
        final currentUserId = p['user_id'] as int?;

        var filtered = drugs.where((d) {
          if (q != null) {
            final cleanQ = q.replaceAll('%', '').toLowerCase();
            final matchTrade = (d['trade_name'] as String).toLowerCase().contains(cleanQ);
            final matchInn = (d['inn_name'] as String).toLowerCase().contains(cleanQ);
            if (!matchTrade && !matchInn) return false;
          }
          if (district != null) {
            final hasInDistrict = branchInventory.any((bi) {
              if (bi['drug_id'] != d['id']) return false;
              final b = branches.firstWhere((br) => br['id'] == bi['branch_id'], orElse: () => {});
              return b['district'] == district;
            });
            if (!hasInDistrict) return false;
          }
          if (inStock) {
            final hasStock = branchInventory.any(
              (bi) => bi['drug_id'] == d['id'] && bi['is_available'] == true && (bi['quantity'] as int) > 0,
            );
            if (!hasStock) return false;
          }
          return true;
        }).toList();

        final results = <Map<String, dynamic>>[];
        for (final d in filtered) {
          final invs = branchInventory
              .where((bi) => bi['drug_id'] == d['id'] && bi['is_available'] == true && (bi['quantity'] as int) > 0)
              .toList();

          double? minPrice;
          double? maxPrice;
          if (invs.isNotEmpty) {
            final prices = invs.map((i) => (i['price'] as num).toDouble()).toList();
            prices.sort();
            minPrice = prices.first;
            maxPrice = prices.last;
          }

          final branchCount = invs.map((i) => i['branch_id']).toSet().length;
          final isSaved = currentUserId != null &&
              savedDrugs.any((sd) => sd['drug_id'] == d['id'] && sd['user_id'] == currentUserId);

          results.add({
            'id': d['id'],
            'trade_name': d['trade_name'],
            'inn_name': d['inn_name'],
            'form': d['form'],
            'dosage': d['dosage'],
            'manufacturer': d['manufacturer'],
            'prescription_required': d['prescription_required'],
            'description': d['description'],
            'min_price': minPrice,
            'max_price': maxPrice,
            'pharmacy_count': branchCount,
            'is_saved': isSaved,
          });
        }

        // sorting
        if (s.contains('min_price DESC')) {
          results.sort((a, b) => ((b['min_price'] as num?) ?? -1).compareTo((a['min_price'] as num?) ?? -1));
        } else {
          results.sort((a, b) => ((a['min_price'] as num?) ?? 99999999).compareTo((b['min_price'] as num?) ?? 99999999));
        }

        final paged = results.skip(offset).take(limit).toList();
        return paged;
      }

      // 6. DRUGS: Single drug by id
      if (s.contains('FROM drugs d') && s.contains('WHERE d.id = @id')) {
        final id = p['id'] as int?;
        final currentUserId = p['user_id'] as int?;
        final d = drugs.where((item) => item['id'] == id).firstOrNull;
        if (d == null) return [];

        final invs = branchInventory
            .where((bi) => bi['drug_id'] == d['id'] && bi['is_available'] == true && (bi['quantity'] as int) > 0)
            .toList();

        double? minPrice;
        double? maxPrice;
        if (invs.isNotEmpty) {
          final prices = invs.map((i) => (i['price'] as num).toDouble()).toList();
          prices.sort();
          minPrice = prices.first;
          maxPrice = prices.last;
        }

        final branchCount = invs.map((i) => i['branch_id']).toSet().length;
        final isSaved = currentUserId != null &&
            savedDrugs.any((sd) => sd['drug_id'] == d['id'] && sd['user_id'] == currentUserId);

        return [
          {
            ...d,
            'min_price': minPrice,
            'max_price': maxPrice,
            'pharmacy_count': branchCount,
            'is_saved': isSaved,
          }
        ];
      }

      // 7. DRUGS: Drug prices
      if (s.contains('FROM branch_inventory bi') && s.contains('WHERE bi.drug_id = @drug_id')) {
        final drugId = p['drug_id'] as int?;
        final district = p['district'] as String?;

        final invs = branchInventory.where((bi) {
          if (bi['drug_id'] != drugId) return false;
          if (bi['is_available'] != true || (bi['quantity'] as int) <= 0) return false;
          final b = branches.firstWhere((br) => br['id'] == bi['branch_id'], orElse: () => {});
          if (b['is_active'] != true) return false;
          if (district != null && b['district'] != district) return false;
          return true;
        }).toList();

        final rows = invs.map((bi) {
          final b = branches.firstWhere((br) => br['id'] == bi['branch_id']);
          final pharma = pharmacies.firstWhere((ph) => ph['id'] == b['pharmacy_id']);
          return {
            'id': bi['id'],
            'branch_id': bi['branch_id'],
            'price': bi['price'],
            'quantity': bi['quantity'],
            'is_available': bi['is_available'],
            'b_id': b['id'],
            'b_name': b['name'],
            'district': b['district'],
            'address': b['address'],
            'landmark': b['landmark'],
            'b_phone': b['phone'],
            'working_hours': b['working_hours'],
            'pharmacy_name': pharma['name'],
          };
        }).toList();

        if (s.contains('bi.price DESC')) {
          rows.sort((a, b) => (b['price'] as num).compareTo(a['price'] as num));
        } else {
          rows.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
        }

        return rows;
      }

      // 8. DRUGS: Analogs (inn lookup)
      if (s.contains('SELECT inn_name FROM drugs WHERE id = @id')) {
        final id = p['id'] as int?;
        final d = drugs.where((item) => item['id'] == id).firstOrNull;
        if (d != null) return [{'inn_name': d['inn_name']}];
        return [];
      }

      // DRUGS: Analogs query
      if (s.contains('WHERE LOWER(d.inn_name) = LOWER(@inn_name)') && s.contains('d.id != @current_id')) {
        final inn = (p['inn_name'] as String?)?.toLowerCase();
        final currentId = p['current_id'] as int?;

        final matching = drugs.where((d) => (d['inn_name'] as String).toLowerCase() == inn && d['id'] != currentId).toList();
        return matching.map((d) {
          final invs = branchInventory.where((bi) => bi['drug_id'] == d['id'] && bi['is_available'] == true && (bi['quantity'] as int) > 0);
          double? minPrice;
          if (invs.isNotEmpty) {
            final prices = invs.map((i) => (i['price'] as num).toDouble()).toList();
            prices.sort();
            minPrice = prices.first;
          }
          return {
            'id': d['id'],
            'trade_name': d['trade_name'],
            'inn_name': d['inn_name'],
            'form': d['form'],
            'dosage': d['dosage'],
            'manufacturer': d['manufacturer'],
            'min_price': minPrice,
          };
        }).toList();
      }

      // 9. FAVORITES: List
      if (s.contains('FROM saved_drugs sd') && s.contains('WHERE sd.user_id = @user_id')) {
        final userId = p['user_id'] as int?;
        final userSaved = savedDrugs.where((sd) => sd['user_id'] == userId).toList();
        return userSaved.map((sd) {
          final d = drugs.firstWhere((item) => item['id'] == sd['drug_id']);
          final invs = branchInventory.where((bi) => bi['drug_id'] == d['id'] && bi['is_available'] == true && (bi['quantity'] as int) > 0);
          double? minPrice;
          if (invs.isNotEmpty) {
            final prices = invs.map((i) => (i['price'] as num).toDouble()).toList();
            prices.sort();
            minPrice = prices.first;
          }
          final phCount = invs.map((i) => i['branch_id']).toSet().length;

          return {
            'saved_id': sd['id'],
            'drug_id': sd['drug_id'],
            'saved_at': sd['saved_at'],
            'trade_name': d['trade_name'],
            'inn_name': d['inn_name'],
            'form': d['form'],
            'dosage': d['dosage'],
            'manufacturer': d['manufacturer'],
            'min_price': minPrice,
            'pharmacy_count': phCount,
          };
        }).toList();
      }

      // Check if drug exists
      if (s.contains('SELECT id FROM drugs WHERE id = @drug_id') || s.contains('SELECT id FROM drugs WHERE id = @id')) {
        final id = (p['drug_id'] ?? p['id']) as int?;
        final d = drugs.where((item) => item['id'] == id).firstOrNull;
        return d != null ? [{'id': d['id']}] : [];
      }

      // FAVORITES: Check if saved
      if (s.contains('FROM saved_drugs') && s.contains('WHERE user_id = @user_id AND drug_id = @drug_id')) {
        final uId = p['user_id'] as int?;
        final dId = p['drug_id'] as int?;
        final exists = savedDrugs.where((sd) => sd['user_id'] == uId && sd['drug_id'] == dId).firstOrNull;
        return exists != null ? [{'id': exists['id']}] : [];
      }

      // 10. PHARMACIST: get branch id for user
      if (s.contains('FROM branch_staff WHERE user_id = @user_id')) {
        final uId = p['user_id'] as int?;
        final staff = branchStaff.where((bs) => bs['user_id'] == uId).firstOrNull;
        return staff != null ? [{'branch_id': staff['branch_id']}] : [];
      }

      // PHARMACIST: get branch info
      if (s.contains('FROM branches b') && s.contains('WHERE b.id = @branch_id')) {
        final bId = p['branch_id'] as int?;
        final b = branches.where((item) => item['id'] == bId).firstOrNull;
        if (b == null) return [];
        final ph = pharmacies.firstWhere((p) => p['id'] == b['pharmacy_id']);
        return [{...b, 'pharmacy_name': ph['name']}];
      }

      // PHARMACIST: update branch info
      if (s.contains('UPDATE branches') && s.contains('WHERE id = @branch_id')) {
        final bId = p['branch_id'] as int?;
        final b = branches.where((item) => item['id'] == bId).firstOrNull;
        if (b == null) return [];
        if (p['address'] != null) b['address'] = p['address'];
        if (p['landmark'] != null) b['landmark'] = p['landmark'];
        if (p['phone'] != null) b['phone'] = p['phone'];
        if (p['working_hours'] != null) b['working_hours'] = p['working_hours'];
        return [b];
      }

      // PHARMACIST: get inventory
      if (s.contains('FROM branch_inventory bi') && s.contains('WHERE bi.branch_id = @branch_id')) {
        final bId = p['branch_id'] as int?;
        final q = p['q'] as String?;

        var items = branchInventory.where((bi) => bi['branch_id'] == bId).toList();
        if (s.contains('bi.is_available = true AND bi.quantity > 0')) {
          items = items.where((i) => i['is_available'] == true && (i['quantity'] as int) > 0).toList();
        } else if (s.contains('(bi.is_available = false OR bi.quantity <= 0)')) {
          items = items.where((i) => i['is_available'] == false || (i['quantity'] as int) <= 0).toList();
        }

        if (q != null) {
          final cleanQ = q.replaceAll('%', '').toLowerCase();
          items = items.where((i) {
            final d = drugs.firstWhere((dr) => dr['id'] == i['drug_id']);
            return (d['trade_name'] as String).toLowerCase().contains(cleanQ) ||
                (d['inn_name'] as String).toLowerCase().contains(cleanQ);
          }).toList();
        }

        return items.map((bi) {
          final d = drugs.firstWhere((dr) => dr['id'] == bi['drug_id']);
          return {
            'id': bi['id'],
            'branch_id': bi['branch_id'],
            'drug_id': bi['drug_id'],
            'price': bi['price'],
            'quantity': bi['quantity'],
            'is_available': bi['is_available'],
            'updated_at': bi['updated_at'],
            'trade_name': d['trade_name'],
            'inn_name': d['inn_name'],
            'form': d['form'],
            'dosage': d['dosage'],
            'manufacturer': d['manufacturer'],
          };
        }).toList();
      }

      // PHARMACIST: insert/upsert inventory item
      if (s.contains('INSERT INTO branch_inventory')) {
        final bId = p['branch_id'] as int;
        final dId = p['drug_id'] as int;
        final price = p['price'] as double;
        final qty = p['quantity'] as int;
        final isAvail = p['is_available'] as bool;

        var existing = branchInventory.where((bi) => bi['branch_id'] == bId && bi['drug_id'] == dId).firstOrNull;
        if (existing != null) {
          existing['price'] = price;
          existing['quantity'] = qty;
          existing['is_available'] = isAvail;
          existing['updated_at'] = DateTime.now().toIso8601String();
          return [existing];
        } else {
          final newId = ++_nextInventoryId;
          final newItem = {
            'id': newId,
            'branch_id': bId,
            'drug_id': dId,
            'price': price,
            'quantity': qty,
            'is_available': isAvail,
            'updated_at': DateTime.now().toIso8601String(),
          };
          branchInventory.add(newItem);
          return [newItem];
        }
      }

      // PHARMACIST: check inventory item ownership
      if (s.contains('FROM branch_inventory WHERE id = @id AND branch_id = @branch_id')) {
        final id = p['id'] as int?;
        final bId = p['branch_id'] as int?;
        final found = branchInventory.where((bi) => bi['id'] == id && bi['branch_id'] == bId).firstOrNull;
        return found != null ? [{'id': found['id']}] : [];
      }

      // PHARMACIST: update inventory item
      if (s.contains('UPDATE branch_inventory') && s.contains('WHERE id = @id AND branch_id = @branch_id')) {
        final id = p['id'] as int?;
        final bId = p['branch_id'] as int?;
        final item = branchInventory.where((bi) => bi['id'] == id && bi['branch_id'] == bId).firstOrNull;
        if (item == null) return [];

        if (p['price'] != null) item['price'] = p['price'];
        if (p['quantity'] != null) item['quantity'] = p['quantity'];
        if (p['is_available'] != null) item['is_available'] = p['is_available'];
        item['updated_at'] = DateTime.now().toIso8601String();

        return [item];
      }

      // 11. ADMIN: Dashboard stats
      if (s.contains('SELECT COUNT(*) AS count FROM drugs')) {
        return [{'count': drugs.length}];
      }
      if (s.contains('SELECT COUNT(*) AS count FROM branches WHERE is_active = true')) {
        return [{'count': branches.where((b) => b['is_active'] == true).length}];
      }
      if (s.contains("WHERE r.name = 'pharmacist'")) {
        final pharmRoleId = roles.firstWhere((r) => r['name'] == 'pharmacist')['id'];
        final count = users.where((u) => u['role_id'] == pharmRoleId).length;
        return [{'count': count}];
      }
      if (s.contains('SELECT COUNT(*) AS count FROM users')) {
        return [{'count': users.length}];
      }

      // ADMIN: Insert drug
      if (s.contains('INSERT INTO drugs')) {
        final newId = ++_nextDrugId;
        final newDrug = {
          'id': newId,
          'trade_name': p['trade_name'],
          'inn_name': p['inn_name'],
          'form': p['form'],
          'dosage': p['dosage'],
          'manufacturer': p['manufacturer'],
          'prescription_required': p['prescription_required'] == true,
          'indications': p['indications'],
          'dosage_instructions': p['dosage_instructions'],
          'contraindications': p['contraindications'],
          'storage_conditions': p['storage_conditions'],
          'description': p['description'],
          'created_at': DateTime.now().toIso8601String(),
        };
        drugs.add(newDrug);
        return [newDrug];
      }

      // ADMIN: Update drug
      if (s.contains('UPDATE drugs') && s.contains('WHERE id = @id')) {
        final id = p['id'] as int?;
        final d = drugs.where((item) => item['id'] == id).firstOrNull;
        if (d == null) return [];

        p.forEach((k, v) {
          if (v != null && k != 'id') d[k] = v;
        });
        return [d];
      }

      // ADMIN: Check drug in inventory before delete
      if (s.contains('SELECT COUNT(*) AS count FROM branch_inventory WHERE drug_id = @id')) {
        final id = p['id'] as int?;
        final count = branchInventory.where((bi) => bi['drug_id'] == id).length;
        return [{'count': count}];
      }

      // ADMIN: Get branches list
      if (s.contains('FROM branches b JOIN pharmacies p') && s.contains('ORDER BY b.id ASC')) {
        return branches.map((b) {
          final pharma = pharmacies.firstWhere((ph) => ph['id'] == b['pharmacy_id']);
          final staff = branchStaff.where((bs) => bs['branch_id'] == b['id']).firstOrNull;
          Map<String, dynamic>? userObj;
          if (staff != null) {
            userObj = users.where((u) => u['id'] == staff['user_id']).firstOrNull;
          }
          return {
            ...b,
            'pharmacy_name': pharma['name'],
            'pharmacist_id': userObj?['id'],
            'pharmacist_name': userObj?['full_name'],
            'pharmacist_email': userObj?['email'],
          };
        }).toList();
      }

      // ADMIN: Create branch
      if (s.contains('INSERT INTO branches')) {
        final newId = ++_nextBranchId;
        final newBranch = {
          'id': newId,
          'pharmacy_id': p['pharmacy_id'],
          'name': p['name'],
          'district': p['district'],
          'address': p['address'],
          'landmark': p['landmark'],
          'phone': p['phone'],
          'working_hours': p['working_hours'],
          'is_active': p['is_active'] ?? true,
          'created_at': DateTime.now().toIso8601String(),
        };
        branches.add(newBranch);
        return [newBranch];
      }

      // ADMIN: Update branch status
      if (s.contains('UPDATE branches SET is_active = @is_active WHERE id = @id')) {
        final id = p['id'] as int?;
        final b = branches.where((item) => item['id'] == id).firstOrNull;
        if (b == null) return [];
        b['is_active'] = p['is_active'];
        return [b];
      }

      return [];
    };

    Database.mockExecuteHandler = (String sql, Map<String, dynamic>? parameters) async {
      final s = sql.replaceAll(RegExp(r'\s+'), ' ').trim();
      final p = parameters ?? {};

      // Delete favorite
      if (s.contains('DELETE FROM saved_drugs WHERE id = @id')) {
        final id = p['id'] as int?;
        final before = savedDrugs.length;
        savedDrugs.removeWhere((sd) => sd['id'] == id);
        return before - savedDrugs.length;
      }

      // Insert favorite
      if (s.contains('INSERT INTO saved_drugs (user_id, drug_id)')) {
        savedDrugs.add({
          'id': ++_nextSavedDrugId,
          'user_id': p['user_id'],
          'drug_id': p['drug_id'],
          'saved_at': DateTime.now().toIso8601String(),
        });
        return 1;
      }

      // Delete inventory item
      if (s.contains('DELETE FROM branch_inventory WHERE id = @id AND branch_id = @branch_id')) {
        final id = p['id'] as int?;
        final bId = p['branch_id'] as int?;
        final before = branchInventory.length;
        branchInventory.removeWhere((bi) => bi['id'] == id && bi['branch_id'] == bId);
        return before - branchInventory.length;
      }

      // Delete drug
      if (s.contains('DELETE FROM drugs WHERE id = @id')) {
        final id = p['id'] as int?;
        final before = drugs.length;
        drugs.removeWhere((d) => d['id'] == id);
        return before - drugs.length;
      }

      // Insert branch staff
      if (s.contains('INSERT INTO branch_staff')) {
        branchStaff.add({
          'user_id': p['user_id'],
          'branch_id': p['branch_id'],
        });
        return 1;
      }

      return 0;
    };
  }

  static void reset() {
    roles = [
      {'id': 1, 'name': 'admin'},
      {'id': 2, 'name': 'pharmacist'},
      {'id': 3, 'name': 'user'},
    ];

    users = [
      {
        'id': 1,
        'full_name': 'Tizim Administratori',
        'email': 'admin@pharma.uz',
        'password_hash': PasswordHasher.hash('admin12345'),
        'phone': '+998 90 111-22-33',
        'role_id': 1,
        'is_blocked': false,
        'created_at': '2026-10-01T10:00:00Z',
      },
      {
        'id': 2,
        'full_name': 'Sardor Aliyev (Farmatsevt)',
        'email': 'pharmacist@pharma.uz',
        'password_hash': PasswordHasher.hash('pharm12345'),
        'phone': '+998 90 444-55-66',
        'role_id': 2,
        'is_blocked': false,
        'created_at': '2026-10-01T10:00:00Z',
      },
      {
        'id': 3,
        'full_name': 'Anvar Karimov (Mijoz)',
        'email': 'client@pharma.uz',
        'password_hash': PasswordHasher.hash('user12345'),
        'phone': '+998 90 777-88-99',
        'role_id': 3,
        'is_blocked': false,
        'created_at': '2026-10-01T10:00:00Z',
      },
      {
        'id': 4,
        'full_name': 'Bloklangan Foydalanuvchi',
        'email': 'blocked@pharma.uz',
        'password_hash': PasswordHasher.hash('user12345'),
        'phone': '+998 90 000-00-00',
        'role_id': 3,
        'is_blocked': true,
        'created_at': '2026-10-01T10:00:00Z',
      },
    ];

    pharmacies = [
      {'id': 1, 'name': 'Grand Pharm', 'phone': '+998 71 200-00-01'},
      {'id': 2, 'name': 'OxyMed', 'phone': '+998 71 200-00-02'},
      {'id': 3, 'name': 'Best Pharmacy', 'phone': '+998 71 200-00-03'},
    ];

    branches = [
      {
        'id': 1,
        'pharmacy_id': 1,
        'name': 'Chilonzor filiali',
        'district': 'Chilonzor',
        'address': 'Chilonzor 9-mavze, 12-uy',
        'landmark': 'Rayhon milliy taomlari ro‘parasi',
        'phone': '+998 71 200-00-01',
        'working_hours': '08:00 - 23:00',
        'is_active': true,
      },
      {
        'id': 2,
        'pharmacy_id': 2,
        'name': 'Yunusobod filiali',
        'district': 'Yunusobod',
        'address': 'Amir Temur shox ko‘chasi, 45-uy',
        'landmark': 'Megaplanet savdo majmuasi yonida',
        'phone': '+998 71 200-00-02',
        'working_hours': '24/7 (Kun-u tun)',
        'is_active': true,
      },
      {
        'id': 3,
        'pharmacy_id': 3,
        'name': 'Mirzo Ulug‘bek filiali',
        'district': 'Mirzo Ulug‘bek',
        'address': 'Buyuk Ipak Yo‘li ko‘chasi, 102-uy',
        'landmark': 'Buyuk Ipak Yo‘li metro bekati',
        'phone': '+998 71 200-00-03',
        'working_hours': '08:00 - 22:00',
        'is_active': true,
      },
    ];

    branchStaff = [
      {'user_id': 2, 'branch_id': 1},
    ];

    drugs = [
      {
        'id': 1,
        'trade_name': 'PARATSETAMOL',
        'inn_name': 'Paracetamol',
        'form': 'Tabletka',
        'dosage': '500 mg',
        'manufacturer': 'Farmak, Ukraina',
        'prescription_required': false,
        'indications': 'Isitma va og‘riq sindromi',
        'dosage_instructions': '1-2 tabletka kuniga 4 mahal',
        'contraindications': 'Jigar yetishmovchiligi',
        'storage_conditions': '25°C gacha',
        'description': 'Isitma tushiruvchi preparat',
      },
      {
        'id': 2,
        'trade_name': 'IBUPROFEN',
        'inn_name': 'Ibuprofen',
        'form': 'Tabletka',
        'dosage': '400 mg',
        'manufacturer': 'Borisov, Belarus',
        'prescription_required': false,
        'indications': 'Og‘riq qoldiruvchi',
        'dosage_instructions': '1 tabletkadan 3 mahal',
        'contraindications': 'Oshqozon yarasi',
        'storage_conditions': '25°C gacha',
        'description': 'Shamollashga qarshi preparat',
      },
      {
        'id': 3,
        'trade_name': 'KARDIOMAGNIL',
        'inn_name': 'Acetylsalicylic acid',
        'form': 'Tabletka',
        'dosage': '75 mg',
        'manufacturer': 'Takeda, Yaponiya',
        'prescription_required': false,
        'indications': 'Yurak profilaktikasi',
        'dosage_instructions': 'Kuniga 1 tabletka',
        'contraindications': 'Astma',
        'storage_conditions': 'Quruq joyda',
        'description': 'Aspirin tabletkasi',
      },
      {
        'id': 4,
        'trade_name': 'SITRAMON P',
        'inn_name': 'Paracetamol + Acetylsalicylic acid + Caffeine',
        'form': 'Tabletka',
        'dosage': 'Standart',
        'manufacturer': 'Nobel Pharmsanoat',
        'prescription_required': false,
        'indications': 'Bosh og‘rig‘i',
        'dosage_instructions': '1 tabletka',
        'contraindications': 'Yara',
        'storage_conditions': 'Xona haroratida',
        'description': 'Kombinatsiyalangan analgetik',
      },
      {
        'id': 10,
        'trade_name': 'PARATSETAMOL EXTRA',
        'inn_name': 'Paracetamol',
        'form': 'Tabletka',
        'dosage': '500 mg',
        'manufacturer': 'DentaFill Plyus',
        'prescription_required': false,
        'indications': 'Isitma',
        'dosage_instructions': '1 tabletka',
        'contraindications': 'Jigar',
        'storage_conditions': 'Quruq joyda',
        'description': 'Analog dori',
      },
    ];

    branchInventory = [
      {'id': 1, 'branch_id': 1, 'drug_id': 1, 'price': 4200.0, 'quantity': 24, 'is_available': true, 'updated_at': '2026-10-10T10:00:00Z'},
      {'id': 2, 'branch_id': 2, 'drug_id': 1, 'price': 4500.0, 'quantity': 15, 'is_available': true, 'updated_at': '2026-10-10T10:00:00Z'},
      {'id': 3, 'branch_id': 3, 'drug_id': 1, 'price': 5000.0, 'quantity': 32, 'is_available': true, 'updated_at': '2026-10-10T10:00:00Z'},
      {'id': 4, 'branch_id': 1, 'drug_id': 2, 'price': 7500.0, 'quantity': 18, 'is_available': true, 'updated_at': '2026-10-10T10:00:00Z'},
      {'id': 5, 'branch_id': 2, 'drug_id': 2, 'price': 8200.0, 'quantity': 12, 'is_available': true, 'updated_at': '2026-10-10T10:00:00Z'},
      {'id': 6, 'branch_id': 1, 'drug_id': 3, 'price': 18500.0, 'quantity': 30, 'is_available': true, 'updated_at': '2026-10-10T10:00:00Z'},
      {'id': 7, 'branch_id': 2, 'drug_id': 3, 'price': 19500.0, 'quantity': 22, 'is_available': true, 'updated_at': '2026-10-10T10:00:00Z'},
      {'id': 8, 'branch_id': 3, 'drug_id': 3, 'price': 21000.0, 'quantity': 14, 'is_available': true, 'updated_at': '2026-10-10T10:00:00Z'},
      {'id': 9, 'branch_id': 1, 'drug_id': 10, 'price': 3500.0, 'quantity': 40, 'is_available': true, 'updated_at': '2026-10-10T10:00:00Z'},
    ];

    savedDrugs = [
      {'id': 1, 'user_id': 3, 'drug_id': 3, 'saved_at': '2026-10-25T10:00:00Z'},
    ];
  }
}
