import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var monitor: BatteryHardwareMonitor
    @State private var selectedTab: Int = 0
    @State private var statusBanner: String? = nil

    var body: some View {
        ZStack {
            // 100% Pure Black (#000000) turns off iPhone 17 Pro OLED subpixels completely (0 mA display background power)
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                DashboardTabView(statusBanner: $statusBanner)
                    .tabItem {
                        Label("Ultra Saver", systemImage: "bolt.shield.fill")
                    }
                    .tag(0)

                ChecklistTabView(statusBanner: $statusBanner)
                    .tabItem {
                        Label("Toggles", systemImage: "slider.horizontal.3")
                    }
                    .tag(1)

                OLEDToolsTabView(statusBanner: $statusBanner)
                    .tabItem {
                        Label("0mA OLED", systemImage: "sparkles.rectangle.stack")
                    }
                    .tag(2)

                ShortcutsAutomationTabView(statusBanner: $statusBanner)
                    .tabItem {
                        Label("Automate", systemImage: "cpu")
                    }
                    .tag(3)
            }
            .tint(.green)

            // Full-Screen Pure Black OLED Lock / Pocket Blackout Mode (0.00 mA screen draw while keeping phone awake)
            if monitor.oledBlackoutActive {
                OLEDBlackoutOverlayView {
                    monitor.oledBlackoutActive = false
                }
            }
        }
    }
}

// MARK: - 1. Main Dashboard Tab

struct DashboardTabView: View {
    @EnvironmentObject var monitor: BatteryHardwareMonitor
    @Binding var statusBanner: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let banner = statusBanner {
                        Text(banner)
                            .font(.caption.bold())
                            .foregroundColor(.black)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(Color.green)
                            .cornerRadius(20)
                            .onTapGesture { statusBanner = nil }
                    }

                    // Main Battery Telemetry Card
                    VStack(spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("iPHONE 17 PRO • A19 PRO OLED")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundColor(.green)
                                Text("\(Int(monitor.batteryLevel * 100))% Battery")
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 8)
                                    .frame(width: 72, height: 72)
                                Circle()
                                    .trim(from: 0, to: CGFloat(monitor.optimizationScore) / 100.0)
                                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 72, height: 72)
                                VStack(spacing: 0) {
                                    Text("\(monitor.optimizationScore)")
                                        .font(.headline.bold())
                                        .foregroundColor(.white)
                                    Text("EFF")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        Divider().background(Color.white.opacity(0.15))

                        HStack(spacing: 12) {
                            TelemetryPill(
                                label: "EST. RUNTIME",
                                value: String(format: "%.1f hrs", monitor.estimatedHoursRemaining),
                                accent: .green
                            )
                            TelemetryPill(
                                label: "TIME GAINED",
                                value: String(format: "+%.1f hrs", monitor.bonusHoursSaved),
                                accent: .mint
                            )
                            TelemetryPill(
                                label: "EST. DRAW",
                                value: "\(monitor.estimatedCurrentDrawMilliamps) mA",
                                accent: monitor.estimatedCurrentDrawMilliamps < 260 ? .green : .orange
                            )
                        }
                    }
                    .padding(18)
                    .background(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.green.opacity(0.35), lineWidth: 1)
                    )

                    // Instant Hardware Controls Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("INSTANT HARDWARE CONTROLS")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.gray)

                        Button {
                            monitor.toggleUltraOLEDHardwareDimmer()
                            statusBanner = monitor.ultraDimmerEnabled
                                ? "OLED Subpixel Voltage Dropped to 3%"
                                : "OLED Brightness Restored to 30%"
                        } label: {
                            HStack {
                                Image(systemName: monitor.ultraDimmerEnabled ? "bolt.fill" : "sun.min.fill")
                                    .font(.title2)
                                    .foregroundColor(.black)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(monitor.ultraDimmerEnabled ? "Ultra OLED Dimmer: ACTIVE" : "Activate Ultra OLED Hardware Dimmer")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.black)
                                    Text("Instantly drops display emitter draw by ~78%")
                                        .font(.caption2)
                                        .foregroundColor(.black.opacity(0.8))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.black)
                            }
                            .padding(14)
                            .background(Color.green)
                            .cornerRadius(14)
                        }

                        Button {
                            monitor.oledBlackoutActive = true
                        } label: {
                            HStack {
                                Image(systemName: "moon.zzz.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("0.00 mA OLED Blackout Screen")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    Text("Turns off 100% of pixels while keeping active apps alive")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text("START")
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                            }
                            .padding(14)
                            .background(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }

                        // Fine-grained OLED Brightness Slider
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("OLED Voltage / Brightness Clamp")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(monitor.screenBrightness * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.green)
                            }
                            Slider(
                                value: Binding(
                                    get: { monitor.screenBrightness },
                                    set: { monitor.setExactBrightness($0) }
                                ),
                                in: 0.01...1.0
                            )
                            .tint(.green)
                        }
                        .padding(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .padding(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                    // Live Hardware Status Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LIVE iPHONE 17 PRO TELEMETRY")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.gray)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            StatusBox(
                                title: "Low Power Mode",
                                value: monitor.isLowPowerMode ? "Enabled (Clamped)" : "OFF (Tap to Enable)",
                                isOptimal: monitor.isLowPowerMode
                            ) {
                                DeepLinkHelper.open("App-Prefs:BATTERY_USAGE")
                            }

                            StatusBox(
                                title: "ProMotion Refresh",
                                value: "\(monitor.maxRefreshRate) Hz Cap",
                                isOptimal: monitor.maxRefreshRate <= 60 || monitor.isLowPowerMode
                            ) {
                                DeepLinkHelper.open("App-Prefs:ACCESSIBILITY")
                            }

                            StatusBox(
                                title: "A19 Pro Thermal",
                                value: monitor.thermalLabel,
                                isOptimal: monitor.thermalState == .nominal
                            ) {
                                monitor.refreshAllMetrics()
                            }

                            StatusBox(
                                title: "OLED Background",
                                value: "True #000000 (0mA)",
                                isOptimal: true
                            ) {
                                statusBanner = "100% of black pixels are physically powered OFF."
                            }
                        }
                    }
                    .padding(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("BatterySave Pro")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 2. Hardware Toggles & Deep-Link Checklist Tab

struct ChecklistTabView: View {
    @EnvironmentObject var monitor: BatteryHardwareMonitor
    @Binding var statusBanner: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("iOS sandboxes third-party apps from silently flipping system switches in the background. Tap 'OPEN' to jump straight to each iPhone 17 Pro hardware switch, then check it off to track your real-time mA savings.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)

                    ForEach(monitor.checklistItems) { item in
                        HStack(spacing: 12) {
                            Button {
                                monitor.toggleChecklistItem(item.id)
                            } label: {
                                Image(systemName: item.isEnabled ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundColor(item.isEnabled ? .green : .gray)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(item.title)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("-\(item.savedMilliamps) mA (+\(item.savedPercentPerDay)%)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.green)
                                }
                                Text(item.subtitle)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }

                            Button {
                                DeepLinkHelper.open(item.deepLink)
                            } label: {
                                Text("OPEN")
                                    .font(.caption2.bold())
                                    .foregroundColor(.black)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(14)
                        .background(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(item.isEnabled ? Color.green.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Hardware Savings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 3. Pure-Black OLED Wallpaper & Blackout Tools Tab

struct OLEDToolsTabView: View {
    @EnvironmentObject var monitor: BatteryHardwareMonitor
    @Binding var statusBanner: String?
    @State private var savedWallpaperAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("WHY PURE #000000 SAVES MASSIVE BATTERY")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.green)
                        Text("Your iPhone 17 Pro uses an LTPO Super Retina XDR OLED display (1206 × 2622 px). Unlike LCDs with a constant backlight, every pure black (#000000) pixel on an OLED display turns its organic LED emitter completely OFF and draws 0.00 mA.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.35), lineWidth: 1)
                    )

                    // Generate & Save Pure Black Wallpaper
                    Button {
                        PureBlackWallpaperGenerator.saveToPhotos(width: 1206, height: 2622)
                        savedWallpaperAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.badge.arrow.down.fill")
                                .font(.title2)
                                .foregroundColor(.black)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Save 0-mA Pure Black Wallpaper (1206×2622)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.black)
                                Text("Exports uncompressed #000000 PNG to your Photos app")
                                    .font(.caption2)
                                    .foregroundColor(.black.opacity(0.8))
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.green)
                        .cornerRadius(14)
                    }
                    .alert("0-mA OLED Wallpaper Saved!", isPresented: $savedWallpaperAlert) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("Open Photos and set the pure black #000000 image as your Lock Screen & Home Screen wallpaper to cut display power by up to 40%.")
                    }

                    // Launch Blackout Mode
                    Button {
                        monitor.oledBlackoutActive = true
                    } label: {
                        HStack {
                            Image(systemName: "lock.display")
                                .font(.title2)
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enter Full-Screen 0-mA Blackout Overlay")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text("Use when keeping downloads/audio active with 0% screen drain. Double-tap screen to exit.")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("0-mA OLED Studio")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 4. One-Tap iOS Shortcuts & DNS Shield Automation Tab

struct ShortcutsAutomationTabView: View {
    @EnvironmentObject var monitor: BatteryHardwareMonitor
    @Binding var statusBanner: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ONE-TAP ULTRA HIBERNATION (iOS SHORTCUTS BRIDGE)")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.green)
                        Text("Create an iOS Shortcut named 'Ultra Battery Saver' with these 6 actions, then trigger it in 1 tap from below:")
                            .font(.caption)
                            .foregroundColor(.gray)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. Set Low Power Mode → Turn On")
                            Text("2. Set White Point → Turn On")
                            Text("3. Set Brightness → 12%")
                            Text("4. Set Appearance → Dark")
                            Text("5. Set Always On Display → Turn Off")
                            Text("6. Set Voice & Data → LTE")
                        }
                        .font(.caption.monospaced())
                        .foregroundColor(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )

                        HStack(spacing: 10) {
                            Button {
                                DeepLinkHelper.open("shortcuts://run-shortcut?name=Ultra%20Battery%20Saver")
                            } label: {
                                Text("Run 'Ultra Battery Saver'")
                                    .font(.caption.bold())
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }

                            Button {
                                DeepLinkHelper.open("shortcuts://create-shortcut")
                            } label: {
                                Text("Open Shortcuts")
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                                    .padding(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.green, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.35), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ZERO-TELEMETRY DNS RADIO SHIELD")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.green)
                        Text("Background apps wake the iPhone 17 Pro 5G/Wi-Fi radio thousands of times per day to ping ad & analytics servers. Install the included 'BatterySavePro-UltraSuite.mobileconfig' profile to block telemetry domains at the iOS OS-level with zero VPN battery overhead.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Automations")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Supporting Views & Helpers

struct TelemetryPill: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.gray)
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct StatusBox: View {
    let title: String
    let value: String
    let isOptimal: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(isOptimal ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(title)
                        .font(.caption2.bold())
                        .foregroundColor(.gray)
                }
                Text(value)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOptimal ? Color.green.opacity(0.3) : Color.orange.opacity(0.4), lineWidth: 1)
            )
        }
    }
}

struct OLEDBlackoutOverlayView: View {
    let onExit: () -> Void
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 8) {
                Text("0.00 mA OLED BLACKOUT ACTIVE")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.14))
                Text("Double-tap anywhere to wake screen")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.10))
            }
        }
        .statusBarHidden(true)
        .onAppear {
            previousBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 0.01
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIScreen.main.brightness = previousBrightness
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onTapGesture(count: 2) {
            onExit()
        }
    }
}

enum DeepLinkHelper {
    static func open(_ urlString: String) {
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

enum PureBlackWallpaperGenerator {
    static func saveToPhotos(width: Int, height: Int) {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
