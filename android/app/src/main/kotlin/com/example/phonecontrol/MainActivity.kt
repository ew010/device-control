package com.example.phonecontrol

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "phonecontrol/native_input"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "injectTap" -> {
                        val x = call.argument<Double>("x")
                        val y = call.argument<Double>("y")
                        if (x == null || y == null) {
                            result.success("injectTap failed: invalid args")
                            return@setMethodCallHandler
                        }
                        val msg = InputAccessibilityService.injectTap(x, y)
                        result.success(msg)
                    }

                    "injectDrag" -> {
                        val fromX = call.argument<Double>("fromX")
                        val fromY = call.argument<Double>("fromY")
                        val toX = call.argument<Double>("toX")
                        val toY = call.argument<Double>("toY")
                        if (fromX == null || fromY == null || toX == null || toY == null) {
                            result.success("injectDrag failed: invalid args")
                            return@setMethodCallHandler
                        }
                        val msg = InputAccessibilityService.injectDrag(fromX, fromY, toX, toY)
                        result.success(msg)
                    }

                    "injectText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val msg = InputAccessibilityService.injectText(text)
                        result.success(msg)
                    }

                    "openAccessibilitySettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }

                    "status" -> {
                        val enabled = isAccessibilityServiceEnabled()
                        val bound = InputAccessibilityService.isBound()
                        result.success(
                            "android: accessibilityEnabled=$enabled, serviceBound=$bound"
                        )
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val component = ComponentName(this, InputAccessibilityService::class.java)
        return enabledServices.contains(component.flattenToString())
    }
}
