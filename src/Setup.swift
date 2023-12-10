//
//  Setup.swift - Enumerations and structs used to setup
//  the Bluetooth communication with a hub.
//
//  Created by Marcus Handte on 26.03.23.
//

import Foundation
import CoreBluetooth

/// The enumeration with the UUIDs used for Bluetooth communication with a lego hub.
public enum HubId: String {
    /// The UUID to identify the service.
    case service        = "00001623-1212-EFDE-1623-785FEABCD123"
    /// The UUID of the (only) characteristic of the sérvice which is used to send and receive messages.
    case characteristic = "00001624-1212-EFDE-1623-785FEABCD123"
    
    /// Returns the CBUUID for the id.
    ///
    /// - returns The CBUUID for the id.
    public func toUuid() -> CBUUID {
        return CBUUID(string: self.rawValue)
    }
}

/// The structure of the manufacturer specific data contained in the Bluetooth advertisement of a Lego hub.
public struct DeviceAdvertisement {
    
    /// The state of the button on the hub.
    let buttonState: Bool
    /// The system type, if we can decode it.
    let systemType: SystemType?
    /// The device capabilities.
    let deviceCapabilities: [DeviceCapabilities]
    /// The network type to which the hub was last connected.
    let networkType: NetworkType
    /// The device status.
    let deviceStatus: [DeviceStatus]
    
    /// Tries to extract the manufacturer specific part from the advertisement data and decodes it.
    ///
    /// - parameter advertisementData The advertisement data extracted from the GAP message by CoreBluetooth.
    /// - returns The decoded structure, if decoding is possible.
    public init?(advertisementData: [String : Any]) {
        if let manufacturerSpecific = advertisementData["kCBAdvDataManufacturerData"] as? Data {
            let data = [UInt8](manufacturerSpecific)
            if data.count == 8 && data[0] == 0x97 && data[1] == 0x03 {
                    buttonState = data[2] != 0
                systemType = SystemType(rawValue: data[3])
                deviceCapabilities = DeviceCapabilities.decode(data: data[4])
                networkType = NetworkType.decode(value: data[5])
                deviceStatus = DeviceStatus.decode(data: data[6])
                return
            }
        }
        return nil
    }
}


/// Capabilities annonced by the Bluetooth hub.
public enum DeviceCapabilities: UInt8, CaseIterable {
    /// Supports Central Role
    case central = 0x01
    /// Supports Peripheral Role
    case peripheral = 0x02
    /// Supports LPF2 devices (H/W connectors)
    case hardware = 0x04
    /// Act as a Remote Controller (R/C)
    case remote = 0x08
    
    /// Decodes the device capabilities from the specified byte.
    ///
    /// - parameter data: The byte containing the capabilities.
    /// - returns: The decoded capabilities.
    public static func decode(data: UInt8) -> [DeviceCapabilities] {
        var result: [DeviceCapabilities] = []
        for v in DeviceCapabilities.allCases {
            if data & v.rawValue == v.rawValue {
                result.append(v)
            }
        }
        return result
    }
    
}

/// Status announced by the Bluetooth hub.
public enum DeviceStatus: UInt8, CaseIterable {
    /// I can be Peripheral
    case peripheral = 0x01
    /// I can be Central
    case central = 0x02
    /// Request window: A stretching of the Button Pressed (Adding 1 sec. after release)
    case window = 0x20
    /// Request connect: Hardcoded request
    case connect = 0x80
    
    /// Decodes the device status from the specified byte.
    ///
    /// - parameter data: The byte containing the status.
    /// - returns: The decoded status.
    public static func decode(data: UInt8) -> [DeviceStatus] {
        var result: [DeviceStatus] = []
        for v in DeviceStatus.allCases {
            if data & v.rawValue == v.rawValue {
                result.append(v)
            }
        }
        return result
    }
}
