package com.example.phonecontrol

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Path
import android.os.Build
import android.os.Bundle
import android.util.DisplayMetrics
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class InputAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // No-op: this service is command-driven via MethodChannel.
    }

    override fun onInterrupt() {
        // No-op.
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        if (instance === this) {
            instance = null
        }
        super.onDestroy()
    }

    private fun toAbsX(xNorm: Double): Float {
        val m = screenMetrics()
        return (m.widthPixels * xNorm.coerceIn(0.0, 1.0)).toFloat()
    }

    private fun toAbsY(yNorm: Double): Float {
        val m = screenMetrics()
        return (m.heightPixels * yNorm.coerceIn(0.0, 1.0)).toFloat()
    }

    private fun screenMetrics(): DisplayMetrics {
        val m = DisplayMetrics()
        val wm = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
        @Suppress("DEPRECATION")
        wm?.defaultDisplay?.getRealMetrics(m)
        if (m.widthPixels <= 0 || m.heightPixels <= 0) {
            return resources.displayMetrics
        }
        return m
    }

    private fun dispatchPath(path: Path, durationMs: Long): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs))
            .build()
        return dispatchGesture(gesture, null, null)
    }

    private fun injectTapInternal(xNorm: Double, yNorm: Double): Boolean {
        val x = toAbsX(xNorm)
        val y = toAbsY(yNorm)
        val path = Path().apply { moveTo(x, y) }
        return dispatchPath(path, 60)
    }

    private fun injectDragInternal(
        fromXNorm: Double,
        fromYNorm: Double,
        toXNorm: Double,
        toYNorm: Double,
    ): Boolean {
        val path = Path().apply {
            moveTo(toAbsX(fromXNorm), toAbsY(fromYNorm))
            lineTo(toAbsX(toXNorm), toAbsY(toYNorm))
        }
        return dispatchPath(path, 260)
    }

    private fun injectTextInternal(text: String): Boolean {
        val clean = text.trim()
        if (clean.isEmpty()) {
            return true
        }

        val input = rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        if (input != null) {
            val args = Bundle().apply {
                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, clean)
            }
            if (input.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) {
                return true
            }
            input.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
        }

        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("remote_text", clean))
        return input?.performAction(AccessibilityNodeInfo.ACTION_PASTE) ?: false
    }

    companion object {
        private var instance: InputAccessibilityService? = null

        fun isBound(): Boolean = instance != null

        fun injectTap(xNorm: Double, yNorm: Double): String {
            val service = instance ?: return "injectTap failed: accessibility service not enabled"
            val ok = service.injectTapInternal(xNorm, yNorm)
            return if (ok) {
                "injectTap ok"
            } else {
                "injectTap failed: dispatchGesture rejected"
            }
        }

        fun injectDrag(fromX: Double, fromY: Double, toX: Double, toY: Double): String {
            val service = instance ?: return "injectDrag failed: accessibility service not enabled"
            val ok = service.injectDragInternal(fromX, fromY, toX, toY)
            return if (ok) {
                "injectDrag ok"
            } else {
                "injectDrag failed: dispatchGesture rejected"
            }
        }

        fun injectText(text: String): String {
            val service = instance ?: return "injectText failed: accessibility service not enabled"
            val ok = service.injectTextInternal(text)
            return if (ok) {
                "injectText ok"
            } else {
                "injectText failed: no editable node focused"
            }
        }
    }
}
