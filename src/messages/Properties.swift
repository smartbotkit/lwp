//
//  Properties.swift - Enumerations to represent
//      requests and responses related to hub properties.
//
//  Created by Marcus Handte on 25.03.23.
//

import Foundation

/// An enumeration with the property types of the hub.
public enum PropertyType: UInt8 {
    /// The name sent for advertising.
    case advertisingName = 0x01
    /// The state of the button on the hub.
    case buttonState = 0x02
    /// The firmware version.
    case firmwareVersion = 0x03
    /// The hardware version.
    case hardwareVersion = 0x04
    /// The received signal strength.
    case signalStrength = 0x05
    /// The battery voltage (as percentage).
    case batteryVoltage = 0x06
    /// The battery type.
    case batteryType = 0x07
    /// The manufacturer name.
    case manufacturerName = 0x08
    /// The radio firmware version.
    case radioFirmwareVersion = 0x09
    /// The wireless protocol version.
    case wirelessProtocolVersion = 0x0A
    /// The system type id.
    case systemTypeId = 0x0B
    /// The network type.
    case networkType = 0x0C
    /// The primary mac address of the hub.
    case primaryMacAddress = 0x0D
    /// The secondary mac address of the hub.
    case secondaryMacAdresse = 0x0E
    /// The configured network family of the hub.
    case networkFamily = 0x0F
}

/// An enumeration with constants defining the operations on properties.
public enum PropertyOperation: UInt8 {
    /// Set (Downstream)
    case setProperty = 0x01
    /// Enable Updates (Downstream)
    case enableUpdates = 0x02
    /// Disable Updates (Downstream
    case disableUpdates = 0x03
    /// Reset (Downstream)
    case reset = 0x04
    /// Request Update (Downstream)
    case requestUpdate = 0x05
}

/// An enumeration to define the property requests that can be sent to the hub.
public enum PropertyRequest {
    /// Requests the up to update the specified property.
    ///
    /// - parameter type The property type to update.
    case requestUpdate(type: PropertyType)
    /// Request the hub to change the advertising name.
    ///
    /// - parameter name The new name.
    case setAdvertisingName(name: String)
    /// Enables or disables the subscription to advertisement name changes.
    ///
    /// - parameter enabled True to enable, false to disable.
    case notifyAdvertisingName(enabled: Bool)
    /// Resets the advertisement name of the hub to the default value.
    case resetAdvertisingName
    /// Enables or disables notifications about button state changes.
    ///
    /// - parameter enabled True to enable, false to disable.
    case notifyButtonState(enabled: Bool)
    /// Enables or disables notifications on changes to the signal strength.
    ///
    /// - parameter enabled True to enable, false to disable.
    case notifySignalStrength(enabled: Bool)
    /// Enables or disables notifications on changes to the battery voltage.
    ///
    /// - parameter enabled True to enable, false to disable.
    case notifyBatteryVoltage(enabled: Bool)
    /// Sets the network type.
    ///
    /// - parameter value The new type.
    case setNetworkType(value: UInt8)
    ///  Resets the network type to the default value.
    case resetNetworkType
    /// Sets the network family to the specified value.
    ///
    /// - parameter value The new value.
    case setNetworkFamily(value: UInt8)
    
    /// Encodes the property request as a sequence of bytes.
    ///
    /// - returns The encoded request.
    public func encode() -> [UInt8] {
        switch self {
        case .requestUpdate(type: let type):
            return [ type.rawValue, PropertyOperation.requestUpdate.rawValue]
        case .setAdvertisingName(name: let string):
            let chars = string.utf8.map { UInt8($0) }
            var result = [UInt8](repeating: 0, count: min(14, chars.count) + 2)
            result[0] = PropertyType.advertisingName.rawValue
            result[1] = PropertyOperation.setProperty.rawValue
            for i in 0 ..< min(14, chars.count) {
                result[i + 2] = chars[i]
            }
            return result
        case .notifyAdvertisingName(enabled: let enabled):
            return [ PropertyType.advertisingName.rawValue, enabled ? PropertyOperation.enableUpdates.rawValue : PropertyOperation.disableUpdates.rawValue ]
        case .resetAdvertisingName:
            return [ PropertyType.advertisingName.rawValue, PropertyOperation.reset.rawValue ]
        case .notifyButtonState(enabled: let enabled):
            return [ PropertyType.buttonState.rawValue, enabled ? PropertyOperation.enableUpdates.rawValue : PropertyOperation.disableUpdates.rawValue ]
        case .notifySignalStrength(enabled: let enabled):
            return [ PropertyType.signalStrength.rawValue, enabled ? PropertyOperation.enableUpdates.rawValue : PropertyOperation.disableUpdates.rawValue ]
        case .notifyBatteryVoltage(enabled: let enabled):
            return [ PropertyType.batteryVoltage.rawValue, enabled ? PropertyOperation.enableUpdates.rawValue : PropertyOperation.disableUpdates.rawValue ]
        case .setNetworkType(value: let value):
            return [ PropertyType.networkType.rawValue, PropertyOperation.setProperty.rawValue, value ]
        case .resetNetworkType:
            return [ PropertyType.networkType.rawValue, PropertyOperation.reset.rawValue ]
        case .setNetworkFamily(value: let value):
            return [ PropertyType.networkFamily.rawValue, PropertyOperation.setProperty.rawValue, value ]
        }
    }
}

/// An enumeration to represent property updates sent by the hub.
public enum PropertyUpdate {
    /// Signals an advertising name.
    ///
    /// - parameter name The new name.
    case advertisingName(name: String)
    /// Signals the button state.
    ///
    /// - parameter pressed True if pressed, false otherwise.
    case buttonState(pressed: Bool)
    /// Signals the firmware version
    ///
    /// - parameter version The firmware version.
    case firmwareVersion(version: Version)
    /// Signals the hardware version
    ///
    /// - parameter version The hardware version.
    case hardwareVersion(version: Version)
    /// Signals the current signal strength.
    ///
    /// - parameter rssi The signal strength.
    case signalStrength(rssi: Int8)
    /// Signals the current battery volgate.
    ///
    /// - parameter percent The voltage in percent.
    case batteryVoltage(percent: UInt8)
    /// Signals the current battery type.
    ///
    /// - parameter type The battery type.
    case batteryType(type: BatteryType)
    /// Signals the manufacturer name.
    ///
    /// - parameter name The name.
    case manufacturerName(name: String)
    /// Signals the radio firmware version.
    ///
    /// - parameter version The radio firmware version..
    case radioFirmwareVersion(version: String)
    /// Signals the wireless protocol version.
    ///
    /// - parameter version The wireless protocol version..
    case wirelessProtocolVersion(version: UInt16)
    /// Signals the system type.
    ///
    /// - parameter value The raw value of the system type.
    /// - parameter type The system type for known systems.
    case systemType(value: UInt8, type: SystemType?)
    /// Signals the network type.
    ///
    /// - parameter type The network type.
    case networkType(type: NetworkType)
    /// Signals the primary mac addresse.
    ///
    /// - parameter address The mac address.
    case primaryMac(address: [UInt8])
    /// Signals the secondary mac addresse.
    ///
    /// - parameter address The mac address.
    case secondaryMac(address: [UInt8])
    /// Signals the network family.
    ///
    /// - parameter family The network family.
    case networkFamily(family: UInt8)
    
    /// Decodes a message for a particular property type.
    ///
    /// - parameter type The property type.
    /// - parameter value The value of the update.
    /// - returns The property update or nil, if the value is malformed.
    public static func decode(type: PropertyType, value: [UInt8]) -> PropertyUpdate? {
        switch type {
        case .advertisingName:
            if let name = String(bytes: value, encoding: .ascii) {
                return .advertisingName(name: name)
            }
        case .buttonState:
            return .buttonState(pressed: value[0] != 0)
        case .firmwareVersion:
            return .firmwareVersion(version: Version(data: value, offset: 0))
        case .hardwareVersion:
            return .hardwareVersion(version: Version(data: value, offset: 0))
        case .signalStrength:
            return .signalStrength(rssi: Int8(bitPattern: value[0]))
        case .batteryVoltage:
            return .batteryVoltage(percent: value[0])
        case .batteryType:
            if let battery = BatteryType(rawValue: value[0]) {
                return .batteryType(type: battery)
            }
        case .manufacturerName:
            if let name = String(bytes: value, encoding: .ascii) {
                return .manufacturerName(name: name)
            }
        case .radioFirmwareVersion:
            if let name = String(bytes: value, encoding: .ascii) {
                return .radioFirmwareVersion(version: name)
            }
        case .wirelessProtocolVersion:
            return .wirelessProtocolVersion(version: UInt16(value[1]) << 8 | UInt16(value[0]))
        case .systemTypeId:
            return .systemType(value: value[0], type: SystemType(rawValue: value[0]))
        case .networkType:
            return .networkType(type: NetworkType.decode(value: value[0]))
        case .primaryMacAddress:
            return .primaryMac(address: value)
        case .secondaryMacAdresse:
            return .secondaryMac(address: value)
        case .networkFamily:
            return .networkFamily(family: value[0])
        }
        return nil
    }
}

/// The battery types.
public enum BatteryType: UInt8 {
    /// A regular battery.
    case battery = 0x00
    /// A rechargable battery.
    case rechargable = 0x01
}

/// The known system types.
public enum SystemType: UInt8 {
    /// A wedoo hub.
    case weDoHub        = 0b00000000
    /// A duplo train.
    case duploTrain     = 0b00100000
    /// A boost hub.
    case boostHub       = 0b01000000
    /// A two port hub.
    case twoPortHub     = 0b01000001
    /// Two port handset.
    case twoPortHandset = 0b01000010
    /// Technic hub.
    case technicHub     = 0b10000000
}

/// The network types.
public enum NetworkType {
    /// None.
    case none
    /// Set to a certain value.
    case set(id: UInt8)
    /// Locked.
    case locked
    /// Not locked.
    case notLocked
    /// Dependent on signal.
    case rssiDependent
    /// Disabled.
    case disabled
    /// Unused value.
    case unused
    
    /// Decodes the network type represented by the value.
    ///
    /// - parameter value The value.
    /// - returns The network type.
    public static func decode(value: UInt8)->NetworkType {
        switch value {
        case 0:
            return .none
        case 251:
            return .locked
        case 252:
            return .notLocked
        case 253:
            return .rssiDependent
        case 254:
            return .disabled
        case 255:
            return .unused
        default:
            return .set(id: value)
        }
    }
}
