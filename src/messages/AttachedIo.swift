//
//  AttachedIo.swift - Enumerations releated to changes
//      to the ports of the hub.
//
//  Created by Marcus Handte on 25.03.23.
//

import Foundation

/// The type of changes that may occur to ports.
public enum IoType: UInt8, CaseIterable {
    /// A virtual or hardware port has been removed.
    case detached = 0x00
    /// A hardware port has been added.
    case attached = 0x01
    /// A virtual port has been added.
    case attachedVirtual = 0x02
}

/// The enumeration to encapsulate messages related to port changes.
public enum IoUpdate {
    /// Inidicates the removal of a virtual or hardware port.
    case detached
    /// Indicates the addition of a hardware device to a port.
    ///
    /// - parameter deviceId The id representing the device.
    /// - parameter deviceType The device type (if the device is directly supported).
    /// - parameter hardwareRevision The hardware revision.
    /// - parameter softwareVersion The software version.
    case attached(deviceId: UInt16, deviceType: DeviceType?, hardwareRevision: Version, softwareRevision: Version)
    /// Indicates the addition of a virtual port that combines two hardware ports.
    ///
    /// - parameter portId1 The first hardware port.
    /// - parameter portId2 The second hardware port.
    case attachedVirtual(deviceId: UInt16, deviceType: DeviceType?, portId1: UInt8, portId2: UInt8)

    /// Decodes the io update from an array representing it.
    ///
    /// - parameter type The io type of the update.
    /// - parameter data The data representing the update.
    /// - returns The io udpate, if the message can be decoded or nil, if the message is invalid.
    public static func decode(type: IoType, data: [UInt8]) -> IoUpdate? {
        switch type {
        case .attached:
            let typeValue = (UInt16(data[1]) << 8) | UInt16(data[0])
            return  .attached(deviceId: typeValue, deviceType: DeviceType(rawValue: typeValue), hardwareRevision: Version(data: data, offset: 2), softwareRevision: Version(data: data, offset: 6))
        case .detached:
            return .detached
        case .attachedVirtual:
            let typeValue = (UInt16(data[1]) << 8) | UInt16(data[0])
            return .attachedVirtual(deviceId: typeValue, deviceType: DeviceType(rawValue: typeValue), portId1: data[2], portId2: data[3])
        }
    }
}

/// The device type identifiers. The specification contains more but we do not include them
/// since they are not used by the transformation vehicle. Note that the specification is
/// incomplete. and does not contain some of the device types listed here.
public enum DeviceType: UInt16, CaseIterable {
    /// Voltage (on the hub).
    case voltageSensor = 0x0014
    /// Current (on the hub)
    case currentSensor = 0x0015
    /// RGB Light (on the hub)
    case rgbLight = 0x0017
    /// Accelerometer (built-in)
    case accelerationSensor = 0x0039
    /// Gyroscope (built-in)
    case gyroSensor = 0x003A
    /// Tilt (built-in)
    case tiltSensor = 0x003B
    /// Gesture (built-in)
    case gestureSensor = 0x0036
    /// Temperature (built-in)
    case temperatureSensor = 0x003C
    /// Linear motor (transformation vehicle)
    case linearMotor = 0x002E
}


