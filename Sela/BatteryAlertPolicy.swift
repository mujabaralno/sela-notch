import Foundation

enum BatteryAlert: Equatable {
    case chargerConnected
    case chargerDisconnected
    case lowBattery(percentage: Int)

    var message: String {
        switch self {
        case .chargerConnected: "Charger terhubung"
        case .chargerDisconnected: "Charger dilepas"
        case .lowBattery(let percentage): "Baterai \(percentage)% · Hubungkan charger"
        }
    }

    var compactMessage: String {
        switch self {
        case .chargerConnected: "Charger terhubung"
        case .chargerDisconnected: "Charger dilepas"
        case .lowBattery(let percentage): "Baterai \(percentage)%"
        }
    }

    var symbolName: String {
        switch self {
        case .chargerConnected: "bolt.fill"
        case .chargerDisconnected: "bolt.slash.fill"
        case .lowBattery: "exclamationmark.triangle.fill"
        }
    }
}

struct BatteryAlertPolicy {
    static let lowBatteryThreshold = 20

    private(set) var didWarnLowBattery = false
    private var lastExternalPower: Bool?

    mutating func evaluate(percentage: Int?, externalPower: Bool) -> BatteryAlert? {
        let previousPower = lastExternalPower
        lastExternalPower = externalPower

        if let previousPower, previousPower != externalPower {
            if !externalPower, let percentage, percentage <= Self.lowBatteryThreshold {
                didWarnLowBattery = true
            }
            return externalPower ? .chargerConnected : .chargerDisconnected
        }

        guard let percentage else { return nil }

        if percentage > Self.lowBatteryThreshold {
            didWarnLowBattery = false
        } else if !externalPower, !didWarnLowBattery {
            didWarnLowBattery = true
            return .lowBattery(percentage: percentage)
        }

        return nil
    }
}
