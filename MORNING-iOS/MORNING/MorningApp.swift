import SwiftUI
import HealthKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Task { @MainActor in HealthService.shared.startBackgroundObservation() }
        return true
    }
}

@main
struct MorningApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup { DashboardView() }
    }
}
