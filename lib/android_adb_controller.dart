import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_adb/flutter_adb.dart';
import 'package:flutter_adb/adb_crypto.dart';

class AndroidAdbController extends ChangeNotifier {
  bool enabled = false;
  bool connected = false;
  String status = 'ADB未启用';
  String? lastError;

  String _host = '';
  int _port = 5555;
  AdbCrypto? _crypto;
  SizePx _size = const SizePx(width: 1080, height: 2400);

  bool get available => Platform.isAndroid;

  Future<void> toggleEnabled(bool value) async {
    enabled = value;
    if (!value) {
      connected = false;
      status = 'ADB已关闭';
      notifyListeners();
      return;
    }
    status = 'ADB已开启，等待连接';
    notifyListeners();
  }

  Future<void> connect({required String host, required int port}) async {
    _host = host.trim();
    _port = port;
    lastError = null;

    if (!available) {
      status = '当前平台不支持安卓ADB直连';
      notifyListeners();
      return;
    }
    if (_host.isEmpty) {
      status = '请输入目标设备IP';
      notifyListeners();
      return;
    }

    _crypto ??= AdbCrypto();
    try {
      await Adb.sendSingleCommand(
        'getprop ro.product.model',
        ip: _host,
        port: _port,
        crypto: _crypto!,
      );
      connected = true;
      status = 'ADB已连接 $_host:$_port';
      await _refreshScreenSize();
    } catch (e) {
      connected = false;
      status = 'ADB连接失败';
      lastError = '$e';
    }
    notifyListeners();
  }

  Future<void> injectTap(double xNorm, double yNorm) async {
    if (!await _ensureReady()) {
      return;
    }
    final x = (_size.width * xNorm.clamp(0.0, 1.0)).round();
    final y = (_size.height * yNorm.clamp(0.0, 1.0)).round();
    await _runShell('input tap $x $y');
  }

  Future<void> injectDrag(
    double fromX,
    double fromY,
    double toX,
    double toY,
  ) async {
    if (!await _ensureReady()) {
      return;
    }
    final x1 = (_size.width * fromX.clamp(0.0, 1.0)).round();
    final y1 = (_size.height * fromY.clamp(0.0, 1.0)).round();
    final x2 = (_size.width * toX.clamp(0.0, 1.0)).round();
    final y2 = (_size.height * toY.clamp(0.0, 1.0)).round();
    await _runShell('input swipe $x1 $y1 $x2 $y2 220');
  }

  Future<void> injectText(String text) async {
    if (!await _ensureReady()) {
      return;
    }
    final payload = text
        .trim()
        .replaceAll(' ', '%s')
        .replaceAll('"', '\\"')
        .replaceAll("'", "\\'");
    if (payload.isEmpty) {
      return;
    }
    await _runShell('input text "$payload"');
  }

  Future<void> _refreshScreenSize() async {
    try {
      final out = await Adb.sendSingleCommand(
        'wm size',
        ip: _host,
        port: _port,
        crypto: _crypto!,
      );
      final match = RegExp(r'(\d+)x(\d+)').firstMatch(out);
      if (match != null) {
        final w = int.tryParse(match.group(1) ?? '');
        final h = int.tryParse(match.group(2) ?? '');
        if (w != null && h != null && w > 0 && h > 0) {
          _size = SizePx(width: w, height: h);
          status = 'ADB已连接 $_host:$_port (${w}x$h)';
        }
      }
    } catch (_) {
      // Keep fallback size when query fails.
    }
  }

  Future<void> _runShell(String cmd) async {
    try {
      await Adb.sendSingleCommand(
        cmd,
        ip: _host,
        port: _port,
        crypto: _crypto!,
      );
      status = 'ADB命令执行成功';
      lastError = null;
    } catch (e) {
      connected = false;
      status = 'ADB命令失败';
      lastError = '$e';
    }
    notifyListeners();
  }

  Future<bool> _ensureReady() async {
    if (!enabled) {
      status = 'ADB未启用';
      notifyListeners();
      return false;
    }
    if (connected) {
      return true;
    }
    await connect(host: _host, port: _port);
    return connected;
  }
}

class SizePx {
  const SizePx({required this.width, required this.height});

  final int width;
  final int height;
}
