import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // "gubasic/window": an exported app's window, fitted to its startup form
  // before it is first shown, and closed when its program ends
  // (docs/DESIGN.md D86, D87).
  private var windowChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "gubasic/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let window = self else {
        result(nil)
        return
      }
      switch call.method {
      case "fit":
        let args = call.arguments as? [String: Any] ?? [:]
        window.fit(
          title: args["title"] as? String, width: args["width"] as? Double,
          height: args["height"] as? Double)
        result(nil)
      case "close":
        // Closed as the user would, once the handler has returned; the app
        // ends with its last window.
        DispatchQueue.main.async { window.close() }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    windowChannel = channel

    // An exported app, its project inside (D83), stays invisible until it
    // is fitted, so that it does not appear at one size and jump to
    // another; after two seconds it shows anyway.
    if Bundle.main.path(forResource: "project", ofType: "gbz") != nil {
      self.alphaValue = 0
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
        self?.alphaValue = 1
      }
    }

    // The menus say the app's name where the template says APP_NAME.
    DispatchQueue.main.async {
      let name =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? ProcessInfo.processInfo.processName
      MainFlutterWindow.rename(NSApp.mainMenu, to: name)
    }

    super.awakeFromNib()
  }

  // Gives the window |title|, makes the area inside its frame |width| by
  // |height| points, no larger than the screen's visible area, centres it
  // and shows it.
  private func fit(title: String?, width: Double?, height: Double?) {
    if let title = title, !title.isEmpty {
      self.title = title
    }
    if let width = width, let height = height, width > 0, height > 0 {
      var size = NSSize(width: width, height: height)
      if let visible = (self.screen ?? NSScreen.main)?.visibleFrame {
        let frame = self.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        size.width = min(size.width, visible.width - (frame.width - size.width))
        size.height = min(size.height, visible.height - (frame.height - size.height))
      }
      self.setContentSize(size)
      self.center()
    }
    self.alphaValue = 1
  }

  private static func rename(_ menu: NSMenu?, to name: String) {
    for item in menu?.items ?? [] {
      item.title = item.title.replacingOccurrences(of: "APP_NAME", with: name)
      rename(item.submenu, to: name)
    }
  }
}
