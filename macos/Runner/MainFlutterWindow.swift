import ApplicationServices
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerNativeInputChannel(controller: flutterViewController)

    super.awakeFromNib()
  }

  private func registerNativeInputChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "phonecontrol/native_input",
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "status":
        result("macos: accessibilityTrusted=\(Self.isAccessibilityTrusted(prompt: false))")

      case "openAccessibilitySettings":
        result(Self.openAccessibilitySettings())

      case "injectTap":
        guard let args = call.arguments as? [String: Any],
              let x = args["x"] as? Double,
              let y = args["y"] as? Double
        else {
          result("injectTap failed: invalid args")
          return
        }
        result(Self.injectTap(xNorm: x, yNorm: y))

      case "injectDrag":
        guard let args = call.arguments as? [String: Any],
              let fromX = args["fromX"] as? Double,
              let fromY = args["fromY"] as? Double,
              let toX = args["toX"] as? Double,
              let toY = args["toY"] as? Double
        else {
          result("injectDrag failed: invalid args")
          return
        }
        result(Self.injectDrag(fromX: fromX, fromY: fromY, toX: toX, toY: toY))

      case "injectText":
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String
        else {
          result("injectText failed: invalid args")
          return
        }
        result(Self.injectText(text: text))

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func isAccessibilityTrusted(prompt: Bool) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  private static func openAccessibilitySettings() -> Bool {
    _ = isAccessibilityTrusted(prompt: true)
    return true
  }

  private static func injectTap(xNorm: Double, yNorm: Double) -> String {
    guard isAccessibilityTrusted(prompt: false) else {
      return "injectTap failed: accessibility permission missing"
    }
    let point = normalizedToPoint(xNorm: xNorm, yNorm: yNorm)
    guard let move = CGEvent(
      mouseEventSource: nil,
      mouseType: .mouseMoved,
      mouseCursorPosition: point,
      mouseButton: .left
    ), let down = CGEvent(
      mouseEventSource: nil,
      mouseType: .leftMouseDown,
      mouseCursorPosition: point,
      mouseButton: .left
    ), let up = CGEvent(
      mouseEventSource: nil,
      mouseType: .leftMouseUp,
      mouseCursorPosition: point,
      mouseButton: .left
    ) else {
      return "injectTap failed: event creation failed"
    }

    move.post(tap: .cghidEventTap)
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
    return "injectTap ok"
  }

  private static func injectDrag(fromX: Double, fromY: Double, toX: Double, toY: Double) -> String {
    guard isAccessibilityTrusted(prompt: false) else {
      return "injectDrag failed: accessibility permission missing"
    }

    let start = normalizedToPoint(xNorm: fromX, yNorm: fromY)
    let end = normalizedToPoint(xNorm: toX, yNorm: toY)

    guard let down = CGEvent(
      mouseEventSource: nil,
      mouseType: .leftMouseDown,
      mouseCursorPosition: start,
      mouseButton: .left
    ) else {
      return "injectDrag failed: mousedown event failed"
    }

    down.post(tap: .cghidEventTap)

    let steps = 12
    for i in 1 ... steps {
      let t = Double(i) / Double(steps)
      let point = CGPoint(
        x: start.x + (end.x - start.x) * t,
        y: start.y + (end.y - start.y) * t
      )
      if let dragged = CGEvent(
        mouseEventSource: nil,
        mouseType: .leftMouseDragged,
        mouseCursorPosition: point,
        mouseButton: .left
      ) {
        dragged.post(tap: .cghidEventTap)
      }
      usleep(10_000)
    }

    if let up = CGEvent(
      mouseEventSource: nil,
      mouseType: .leftMouseUp,
      mouseCursorPosition: end,
      mouseButton: .left
    ) {
      up.post(tap: .cghidEventTap)
      return "injectDrag ok"
    }

    return "injectDrag failed: mouseup event failed"
  }

  private static func injectText(text: String) -> String {
    guard isAccessibilityTrusted(prompt: false) else {
      return "injectText failed: accessibility permission missing"
    }
    if text.isEmpty {
      return "injectText ok"
    }

    for scalar in text.unicodeScalars {
      guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
            let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
      else {
        return "injectText failed: key event creation failed"
      }
      var value = UniChar(scalar.value)
      down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &value)
      up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &value)
      down.post(tap: .cghidEventTap)
      up.post(tap: .cghidEventTap)
    }

    return "injectText ok"
  }

  private static func normalizedToPoint(xNorm: Double, yNorm: Double) -> CGPoint {
    let x = max(0.0, min(1.0, xNorm))
    let y = max(0.0, min(1.0, yNorm))
    let screen = NSScreen.main?.frame ?? .zero
    return CGPoint(
      x: screen.minX + screen.width * x,
      y: screen.minY + screen.height * (1.0 - y)
    )
  }
}
