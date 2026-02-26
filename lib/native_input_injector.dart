import 'package:flutter/services.dart';

class NativeInputInjector {
  static const MethodChannel _channel = MethodChannel(
    'phonecontrol/native_input',
  );

  static Future<String> injectTap({
    required double x,
    required double y,
  }) async {
    return _invoke(method: 'injectTap', args: {'x': x, 'y': y});
  }

  static Future<String> injectDrag({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
  }) async {
    return _invoke(
      method: 'injectDrag',
      args: {'fromX': fromX, 'fromY': fromY, 'toX': toX, 'toY': toY},
    );
  }

  static Future<String> injectText({required String text}) async {
    return _invoke(method: 'injectText', args: {'text': text});
  }

  static Future<bool> openAccessibilitySettings() async {
    try {
      final value = await _channel.invokeMethod<bool>(
        'openAccessibilitySettings',
      );
      return value ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> getStatus() async {
    return _invoke(method: 'status', args: const {});
  }

  static Future<String> _invoke({
    required String method,
    required Map<String, dynamic> args,
  }) async {
    try {
      final value = await _channel.invokeMethod<String>(method, args);
      return value ?? '$method: no response';
    } on MissingPluginException {
      return '$method not supported on this platform';
    } catch (e) {
      return '$method failed: $e';
    }
  }
}
