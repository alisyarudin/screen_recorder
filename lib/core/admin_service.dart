import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'logger.dart';

class AdminService {
  static const _channel = MethodChannel('com.jasnita/admin');

  final _commandController = StreamController<String>.broadcast();
  Stream<String> get serverCommands => _commandController.stream;

  Timer? _pollTimer;

  // ── Password (hash disimpan di native UserDefaults) ──────────────────────

  Future<bool> setAdminPassword(String newPassword) async {
    if (!Platform.isMacOS) return false;
    try {
      await _channel.invokeMethod('setAdminPassword', newPassword);
      return true;
    } catch (e) {
      appLogger.e('[Admin] setAdminPassword: $e');
      return false;
    }
  }

  /// Ganti password: verifikasi old dulu di native, lalu set new.
  Future<bool> changeAdminPassword(String oldPassword, String newPassword) async {
    if (!Platform.isMacOS) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'changeAdminPassword', {'old': oldPassword, 'new': newPassword}) ??
          false;
    } catch (e) {
      appLogger.e('[Admin] changeAdminPassword: $e');
      return false;
    }
  }

  Future<bool> clearAdminPassword() async {
    if (!Platform.isMacOS) return false;
    try {
      await _channel.invokeMethod('clearAdminPassword');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasAdminPassword() async {
    if (!Platform.isMacOS) return false;
    try {
      return await _channel.invokeMethod<bool>('hasAdminPassword') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifyAdminPassword(String password) async {
    if (!Platform.isMacOS) return true;
    try {
      return await _channel.invokeMethod<bool>('verifyAdminPassword', password) ?? false;
    } catch (e) {
      return false;
    }
  }

  // ── Auto-start (LaunchAgent dengan KeepAlive) ────────────────────────────

  Future<bool> installAutoStart() async {
    if (!Platform.isMacOS) return false;
    try {
      return await _channel.invokeMethod<bool>('installAutoStart') ?? false;
    } catch (e) {
      appLogger.e('[Admin] installAutoStart: $e');
      return false;
    }
  }

  Future<bool> uninstallAutoStart() async {
    if (!Platform.isMacOS) return false;
    try {
      return await _channel.invokeMethod<bool>('uninstallAutoStart') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> getAutoStartStatus() async {
    if (!Platform.isMacOS) return false;
    try {
      return await _channel.invokeMethod<bool>('getAutoStartStatus') ?? false;
    } catch (e) {
      return false;
    }
  }

  // ── Quit app (hanya dipanggil setelah verifikasi di native) ─────────────

  Future<void> quitApp() async {
    try {
      if (Platform.isMacOS) {
        await _channel.invokeMethod('quitApp');
      } else {
        exit(0);
      }
    } catch (_) {
      exit(0);
    }
  }

  // ── Server control polling ───────────────────────────────────────────────

  void startServerPolling(String url) {
    _pollTimer?.cancel();
    if (url.trim().isEmpty) return;
    appLogger.i('[Admin] Server polling started → $url');
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pollServer(url.trim());
    });
    _pollServer(url.trim());
  }

  void stopServerPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollServer(String url) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'ScreenRecorder-Agent/1.0');
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final cmd = json['command'] as String?;
        if (cmd != null && cmd.isNotEmpty) {
          appLogger.i('[Admin] Server command: $cmd');
          _commandController.add(cmd);
        }
      }
      client.close(force: false);
    } catch (e) {
      appLogger.d('[Admin] Poll failed (server unreachable): $e');
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _commandController.close();
  }
}
