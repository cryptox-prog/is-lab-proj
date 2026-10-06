import Flutter
import UIKit
import CoreMotion

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let orientationHandler = OrientationHandler()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterEventChannel(
      name: "privacy_screen/orientation",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setStreamHandler(orientationHandler)
  }
}

class OrientationHandler: NSObject, FlutterStreamHandler {
  private let motion = CMMotionManager()

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard motion.isDeviceMotionAvailable else {
      return FlutterError(code: "unavailable", message: "Motion sensors are unavailable on this device.", details: nil)
    }
    motion.deviceMotionUpdateInterval = 0.05
    motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { data, error in
      if let error = error {
        events(FlutterError(code: "sensor_error", message: error.localizedDescription, details: nil))
      } else if let data = data {
        events(["theta": data.attitude.pitch, "phi": data.attitude.yaw])
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motion.stopDeviceMotionUpdates()
    return nil
  }
}
