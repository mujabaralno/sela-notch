import AppKit
import IOKit.ps

@MainActor
final class BatteryModel: ObservableObject {
    enum Condition: Equatable {
        case onBattery
        case charging
        case connected
    }

    struct Reading: Equatable {
        var percentage: Int?
        var externalPower: Bool
        var charging: Bool
    }

    @Published private(set) var percentage: Int?
    @Published private(set) var condition: Condition?
    @Published private(set) var hasBattery = true
    @Published private(set) var alert: BatteryAlert?
    @Published var alertsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(alertsEnabled, forKey: Self.alertsKey)
            if !alertsEnabled { clearAlert() }
        }
    }

    private static let alertsKey = "batteryAlertsEnabled"

    private var policy = BatteryAlertPolicy()
    private var poller: Timer?
    private var powerSource: CFRunLoopSource?
    private var alertTask: Task<Void, Never>?

    init() {
        alertsEnabled = UserDefaults.standard.object(forKey: Self.alertsKey) as? Bool ?? true
        refresh()
        startMonitoring()
    }

    deinit {
        poller?.invalidate()
        alertTask?.cancel()
        if let powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .commonModes)
        }
    }

    var conditionText: String {
        guard hasBattery else { return "Informasi baterai tidak tersedia pada perangkat ini" }
        guard let condition else { return "Informasi baterai belum tersedia" }
        switch condition {
        case .onBattery: return "Menggunakan baterai"
        case .charging: return "Sedang mengisi daya"
        case .connected: return "Terhubung ke charger · tidak mengisi"
        }
    }

    func refresh() {
        guard let reading = Self.readReading() else {
            hasBattery = false
            percentage = nil
            condition = nil
            return
        }

        hasBattery = true
        percentage = reading.percentage.map { min(100, max(0, $0)) }
        condition = reading.charging ? .charging : (reading.externalPower ? .connected : .onBattery)

        guard let alert = policy.evaluate(percentage: percentage, externalPower: reading.externalPower),
              alertsEnabled
        else { return }

        show(alert)
    }

    private func show(_ alert: BatteryAlert) {
        alertTask?.cancel()
        self.alert = alert

        alertTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.alert = nil
        }
    }

    private func clearAlert() {
        alertTask?.cancel()
        alertTask = nil
        alert = nil
    }

    private func startMonitoring() {
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 4
        RunLoop.main.add(timer, forMode: .common)
        poller = timer

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let model = Unmanaged<BatteryModel>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in model.refresh() }
        }, context)?.takeRetainedValue() else { return }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        powerSource = source
    }

    private static func readReading() -> Reading? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  description[kIOPSIsPresentKey] as? Bool != false
            else { continue }

            let current = description[kIOPSCurrentCapacityKey] as? Int
            let maximum = description[kIOPSMaxCapacityKey] as? Int
            let percentage = current.flatMap { current in
                maximum.flatMap { maximum in
                    maximum > 0 ? current * 100 / maximum : nil
                }
            }
            let externalPower = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let charging = externalPower && (description[kIOPSIsChargingKey] as? Bool) == true

            return Reading(percentage: percentage, externalPower: externalPower, charging: charging)
        }

        return nil
    }
}
