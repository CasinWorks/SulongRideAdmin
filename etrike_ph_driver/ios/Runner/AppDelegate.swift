import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureGoogleMaps()
    if let controller = window?.rootViewController as? FlutterViewController {
      registerPlatformChannel(on: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    configureGoogleMaps()
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "etrike.platform") {
      registerPlatformChannel(on: registrar.messenger())
    }
  }

  private func configureGoogleMaps() {
#if targetEnvironment(simulator)
    // iOS 26 simulator can render a blank/white map unless Metal is forced early.
    let setMetalSel = NSSelectorFromString("setMetalRendererEnabled:")
    if GMSServices.responds(to: setMetalSel) {
      GMSServices.perform(setMetalSel, with: NSNumber(value: true))
    }
#endif
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String, !apiKey.isEmpty {
      GMSServices.provideAPIKey(apiKey)
    }
  }

  private func registerPlatformChannel(on messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "etrike/platform", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSimulator":
#if targetEnvironment(simulator)
        result(true)
#else
        result(false)
#endif
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
