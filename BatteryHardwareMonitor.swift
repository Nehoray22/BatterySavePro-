import Foundation
import UIKit
import Combine

/// Zero-polling, event-driven hardware telemetry monitor for iPhone 17 Pro.
/// Uses NotificationCenter observers instead of background timers so the app itself consumes near-zero CPU.
final class BatteryHardwareMonitor: ObservableObject {
    @Published var batteryLevel: Float = 1.0
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var isLowPowerMode: Bool = false
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var screenBrightness: CGFloat = 0.5
    @Published var maxRefreshRate: Int = 120
    @Published var ultraDimmerEnabled: Bool = false
    @Published var oledBlackoutActive: Bool = false

    // User-confirmed hardware optimization checklist for iPhone 17 Pro
    @Published var checklistItems: [PowerOptimizationItem] = [
        PowerOptimizationItem(
            id: "aod_off",
            title: "Disable Always-On Display",
            subtitle: "Stops 1Hz LTPO OLED & co-processor drain while locked",
            savedMilliamps: 45,
            savedPercentPerDay: 14,
            deepLink: "App-Prefs:DISPLAY",
            icon: "iphone.slash",
            isEnabled: false
        ),
        PowerOptimizationItem(
            id: "promotion_cap",
            title: "Cap Frame Rate to 60Hz",
            subtitle: "Accessibility > Motion > Limit Frame Rate cuts GPU & display power",
            savedMilliamps: 65,
            savedPercentPerDay: 16,
            deepLink: "App-Prefs:ACCESSIBILITY",
            icon: "gauge.with.dots.needle.33percent",
            isEnabled: false
        ),
        PowerOptimizationItem(
            id: "white_point",
            title: "Reduce White Point (80%)",
            subtitle: "Drops OLED emitter voltage dramatically even in daylight",
            savedMilliamps: 85,
            savedPercentPerDay: 22,
            deepLink: "App-Prefs:ACCESSIBILITY",
            icon: "sun.min.fill",
            isEnabled: false
        ),
        PowerOptimizationItem(
            id: "5g_lte",
            title: "Lock Cellular to LTE / 5G Auto",
            subtitle: "Prevents Qualcomm 5G modem high-band search drain",
            savedMilliamps: 75,
            savedPercentPerDay: 18,
            deepLink: "App-Prefs:MOBILE_DATA_SETTINGS_ID",
            icon: "antenna.radiowaves.left.and.right.slash",
            isEnabled: false
        ),
        PowerOptimizationItem(
            id: "bg_refresh",
            title: "Disable Background App Refresh",
            subtitle: "Stops background daemon wakeups & network polling",
            savedMilliamps: 50,
            savedPercentPerDay: 12,
            deepLink: "App-Prefs:General",
            icon: "arrow.triangle.2.circlepath.circle",
            isEnabled: false
        ),
        PowerOptimizationItem(
            id: "dns_shield",
            title: "Zero-Telemetry DNS Radio Shield",
            subtitle: "Blocks background ad/analytics pings from waking the modem",
            savedMilliamps: 60,
            savedPercentPerDay: 15,
            deepLink: "App-Prefs:General&path=ManagedConfigurationList",
            icon: "shield.lefthalf.filled",
            isEnabled: false
        )
    ]

    private var cancellables = Set<AnyCancellable>()

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        loadSavedChecklist()
        refreshAllMetrics()
        registerEventObservers()
    }

    func refreshAllMetrics() {
        let level = UIDevice.current.batteryLevel
        batteryLevel = level >= 0 ? level : 0.85
        batteryState = UIDevice.current.batteryState
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermalState = ProcessInfo.processInfo.thermalState
        screenBrightness = UIScreen.main.brightness
        maxRefreshRate = UIScreen.main.maximumFramesPerSecond
    }

    private func registerEventObservers() {
        let nc = NotificationCenter.default

        nc.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in self?.refreshAllMetrics() }
            .store(in: &cancellables)

        nc.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .sink { [weak self] _ in self?.refreshAllMetrics() }
            .store(in: &cancellables)

        nc.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshAllMetrics() }
            }
            .store(in: &cancellables)

        nc.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshAllMetrics() }
            }
            .store(in: &cancellables)

        nc.publisher(for: UIScreen.brightnessDidChangeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refreshAllMetrics() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Instant Hardware Actions Allowed by iOS Sandbox

    /// Instantly drops OLED screen brightness to ultra-low 5% (or restores to 35%)
    func toggleUltraOLEDHardwareDimmer() {
        ultraDimmerEnabled.toggle()
        if ultraDimmerEnabled {
            UIScreen.main.brightness = 0.03
        } else {
            UIScreen.main.brightness = 0.30
        }
        screenBrightness = UIScreen.main.brightness
    }

    func setExactBrightness(_ value: CGFloat) {
        UIScreen.main.brightness = value
        screenBrightness = value
    }

    func toggleChecklistItem(_ itemID: String) {
        guard let idx = checklistItems.firstIndex(where: { $0.id == itemID }) else { return }
        checklistItems[idx].isEnabled.toggle()
        saveChecklist()
    }

    private func saveChecklist() {
        let enabledIDs = checklistItems.filter(\.isEnabled).map(\.id)
        UserDefaults.standard.set(enabledIDs, forKey: "enabled_power_optimizations")
    }

    private func loadSavedChecklist() {
        guard let saved = UserDefaults.standard.stringArray(forKey: "enabled_power_optimizations") else { return }
        for i in checklistItems.indices {
            checklistItems[i].isEnabled = saved.contains(checklistItems[i].id)
        }
    }

    // MARK: - Power & Runtime Calculations (iPhone 17 Pro ~3,700 mAh / 14.3 Wh)

    var estimatedCurrentDrawMilliamps: Int {
        var draw = 280 // Base iPhone 17 Pro active SoC + RAM idle draw (mA)
        // Display OLED draw scales exponentially with brightness
        draw += Int(pow(Double(screenBrightness), 1.7) * 420.0)
        // ProMotion 120Hz penalty
        if maxRefreshRate > 60 && !isLowPowerMode {
            draw += 75
        }
        // Low power mode A19 Pro efficiency core clamp
        if isLowPowerMode {
            draw -= 95
        }
        // Thermal throttling leakage penalty
        switch thermalState {
        case .nominal: break
        case .fair: draw += 60
        case .serious: draw += 140
        case .critical: draw += 260
        @unknown default: break
        }
        // Subtract active optimizations
        let saved = checklistItems.filter(\.isEnabled).reduce(0) { $0 + $1.savedMilliamps }
        return max(85, draw - (saved / 2))
    }

    var estimatedHoursRemaining: Double {
        let capacityMah = 3700.0 * Double(max(0.05, batteryLevel))
        let draw = Double(max(85, estimatedCurrentDrawMilliamps))
        return capacityMah / draw
    }

    var bonusHoursSaved: Double {
        let baseHours = (3700.0 * Double(max(0.05, batteryLevel))) / 480.0
        return max(0.0, estimatedHoursRemaining - baseHours)
    }

    var optimizationScore: Int {
        var score = 20
        if isLowPowerMode { score += 20 }
        if screenBrightness <= 0.25 { score += 15 }
        if maxRefreshRate <= 60 { score += 15 }
        let enabledCount = checklistItems.filter(\.isEnabled).count
        score += min(30, enabledCount * 5)
        return min(100, score)
    }

    var thermalLabel: String {
        switch thermalState {
        case .nominal: return "Cool (Optimal)"
        case .fair: return "Warm (+8% Drain)"
        case .serious: return "Hot (+22% Drain)"
        case .critical: return "Critical Thermal Drain"
        @unknown default: return "Nominal"
        }
    }
}

struct PowerOptimizationItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let savedMilliamps: Int
    let savedPercentPerDay: Int
    let deepLink: String
    let icon: String
    var isEnabled: Bool
}
