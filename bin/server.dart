import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:dori_qidiruv_tizimi_backend/app.dart';
import 'package:dori_qidiruv_tizimi_backend/config/database.dart';
import 'package:dori_qidiruv_tizimi_backend/config/env_config.dart';

void main(List<String> args) async {
  // 1. Env sozlamalari
  EnvConfig.init();

  // 2. Baza pool'ini ishga tushirish
  Database.init();
  print(
      '📦 PostgreSQL Connection Pool initsializatsiya qilindi: ${EnvConfig.dbHost}:${EnvConfig.dbPort}/${EnvConfig.dbName}');

  // 3. To'liq server pipeline'ini olish
  final handler = createAppHandler();

  // 4. Serverni ishga tushirish
  final ip = InternetAddress.anyIPv4;
  final port = EnvConfig.port;
  final server = await shelf_io.serve(handler, ip, port);
  server.autoCompress = true;

  print(
      '🚀 PharmaSearch Backend serveri ishga tushdi: http://${server.address.host}:${server.port}');

  // Graceful shutdown
  try {
    ProcessSignal.sigint.watch().listen((_) async {
      print('\n🛑 Server to‘xtatilmoqda...');
      await server.close(force: true);
      await Database.close();
      print('✅ Server va baza ulanishlari yopildi.');
      exit(0);
    });
  } catch (_) {
    // Windows signallari uchun fallback
  }
}
