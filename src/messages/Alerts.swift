//
//  Alerts.swift - Enumerations related to alerts of the hub
//
//  Created by Marcus Handte on 25.03.23.
//

import Foundation

/// The types of alerts that can be raised by the hub.
public enum AlertType: UInt8, CaseIterable {
    /// Low Voltage
    case lowVoltage = 0x01
    /// High Current
    case highCurrent = 0x02
    /// Low Signal Strength
    case lowSignal = 0x03
    /// Over Power Condition
    case overPower = 0x04
}

/// The operations on alerts that can be executed on the hub.
public enum AlertOperation: UInt8, CaseIterable {
    /// Enable Updates (Downstream)
    case enableUpdates = 0x01
    /// Disable Updates (Downstream)
    case disableUpdates = 0x02
    /// Request Update (Downstream)
    case requestUpdate = 0x03
}
    
