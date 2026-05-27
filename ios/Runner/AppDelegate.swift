import GoogleSignIn
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: "382775998205-gmh0c7kk43ddmnp3ir7orbc5asp7bdjf.apps.googleusercontent.com")
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}
