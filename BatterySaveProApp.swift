import SwiftUI

@main
struct BatterySaveProApp: App {
    @StateObject private var monitor = BatteryHardwareMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(monitor)
                .preferredColorScheme(.dark)
        }
    }
}
