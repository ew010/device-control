import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ScrcpyBridge extends ChangeNotifier {
  Process? _scrcpyProcess;
  bool get running => _scrcpyProcess != null;

  String status = '未启动';
  String? lastError;

  Future<void> start({required String host, required int adbPort}) async {
    lastError = null;

    if (!(Platform.isWindows || Platform.isMacOS)) {
      status = '当前平台不支持 scrcpy 直连';
      notifyListeners();
      return;
    }

    final serial = '$host:$adbPort';

    final adbExit = await _runAndCapture('adb', ['connect', serial]);
    if (adbExit.exitCode != 0) {
      lastError = 'adb connect 失败: ${adbExit.stderrOrStdout}';
      status = '启动失败';
      notifyListeners();
      return;
    }

    try {
      final process = await Process.start('scrcpy', ['-s', serial]);
      _scrcpyProcess = process;
      status = '运行中 ($serial)';
      notifyListeners();

      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());

      unawaited(
        process.exitCode.then((code) {
          if (_scrcpyProcess == process) {
            _scrcpyProcess = null;
            status = '已退出 (code=$code)';
            notifyListeners();
          }
        }),
      );
    } catch (e) {
      lastError = '启动 scrcpy 失败，请确认已安装并加入 PATH: $e';
      status = '启动失败';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    final process = _scrcpyProcess;
    _scrcpyProcess = null;
    if (process == null) {
      return;
    }

    process.kill(ProcessSignal.sigterm);
    status = '已停止';
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }

  Future<_ExitResult> _runAndCapture(String cmd, List<String> args) async {
    try {
      final result = await Process.run(cmd, args);
      return _ExitResult(
        exitCode: result.exitCode,
        stdout: result.stdout?.toString() ?? '',
        stderr: result.stderr?.toString() ?? '',
      );
    } catch (e) {
      return _ExitResult(exitCode: 127, stdout: '', stderr: '$cmd 不可用: $e');
    }
  }
}

class _ExitResult {
  const _ExitResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  String get stderrOrStdout {
    final v = stderr.trim().isNotEmpty ? stderr.trim() : stdout.trim();
    if (v.isEmpty) {
      return 'unknown error';
    }
    const limit = 240;
    if (v.length <= limit) {
      return v;
    }
    return '${v.substring(0, limit)}...';
  }
}
