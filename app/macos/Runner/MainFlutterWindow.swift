import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Same first size as the Windows and Linux runners (the desktop layout);
    // the smallest size still fits the phone layout. Window restoration would
    // put back the last frame over this, so it's off.
    self.isRestorable = false
    self.setContentSize(NSSize(width: 1280, height: 720))
    self.contentMinSize = NSSize(width: 360, height: 560)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
