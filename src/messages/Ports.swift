//
//  Ports.swift - Enumerations and structs to represent
//      port and port mode information as well as input
//      values and output commands.
//
//  Created by Marcus Handte on 25.03.23.
//

import Foundation

/// An enumeartion with request types for port information.
public enum PortInformationRequest: UInt8, CaseIterable {
    /// Request the hub to send the port value.
    case portValue = 0x00
    /// Requests the hub to send the mode info.
    case modeInfo = 0x01
    /// Reqests the hub to send the mode combinations.
    case modeCombinations = 0x02
}

/// An enumeartion with the informtatoin types sent by the hub.
public enum PortInformationType: UInt8, CaseIterable {
    /// The mode information.
    case modeInfo = 0x01
    /// The mode combination information.
    case modeCombinations = 0x02
}

/// The enumeration to represent port information messages.
public enum PortInformationUpdate {
    /// The update containing the mode information.
    ///
    /// - parameter input The port is an input port (provides values to the hub).
    /// - parameter ouptut The port is an output port (can control something).
    /// - parameter combinable The port supports multiple mode combinations.
    /// - parameter synchronizable The port can be used in virtual ports to allow synchronized control.
    /// - parameter modeCount The number of modes.
    /// - parameter inputModes The available input modes.
    /// - parameter outputModes The available output modes.
    case modeInfo(input: Bool, output: Bool, combinable: Bool, synchronizable: Bool, modeCount: UInt8, inputModes: [UInt8], outputModes: [UInt8])
    /// The update containing the mode combinations.
    ///
    /// - parameter modeCombnations The supported mode combinations.
    case modeCombinations(modeCombinations: [[UInt8]])
    
    /// Decodes a port information update.
    ///
    /// - parameter type The information type.
    /// - parameter data The data with the information.
    /// - returns The port infromation or null, if the information cannot be extracted.
    public static func decode(type: PortInformationType, data: [UInt8]) -> PortInformationUpdate? {
        switch type {
        case .modeInfo:
            let output = data[0] & 0x01 == 0x01
            let input = data[0] & 0x02 == 0x02
            let combinable = data[0] & 0x04 == 0x04
            let synchronizable = data[0] & 0x08 == 0x08
            let inputModes = UInt16(data[3]) << 8 | UInt16(data[2])
            let outputModes =  UInt16(data[5]) << 8 | UInt16(data[4])
            var inputList: [UInt8] = []
            var outputList: [UInt8] = []
            for i in 0..<16 {
                let value = UInt16(1 << i)
                if inputModes & value == value {
                    inputList.append(UInt8(i))
                }
                if outputModes & value == value {
                    outputList.append(UInt8(i))
                }
            }
            return .modeInfo(input: input, output: output, combinable: combinable, synchronizable: synchronizable, modeCount: data[1], inputModes: inputList , outputModes: outputList)
        case .modeCombinations:
            var combinations: [[UInt8]] = []
            for i in 0..<(data.count / 2) {
                let start = i * 2
                let combs = UInt16(data[start + 1]) << 8 | UInt16(data[start])
                var values: [UInt8] = []
                for j in 0..<16 {
                    if UInt16(1 << j) & combs == UInt16(1 << j) {
                        values.append(UInt8(j))
                    }
                }
                combinations.append(values)
            }
            return .modeCombinations(modeCombinations: combinations)
        }
    }
}

/// An enumearatoion with the port mode types that are used to differentatie individual messages
///     with information on a partciular port mode
public enum PortModeType: UInt8, CaseIterable {
    /// The name of the mode.
    case name = 0x00
    /// The raw value range of the mode.
    case raw = 0x01
    /// The percent range of the mode.
    case pct = 0x02
    /// The si value range of the mode.
    case si = 0x03
    /// The si symbol (e.g. DEG, POS, SPEED, etc.)
    case symbol = 0x04
    /// The port mode mapping describing the value.
    case mapping = 0x05
    /// This case appears to be not working at all.
    case motorBias = 0x07
    /// This case appears to be not working at all.
    case capabilityBits = 0x08
    /// The format and interpretation of the values.
    case valueFormat = 0x80
    
    /// Returns the cases that are functional (i.e. implemented on the hub).
    ///
    /// - returns: The cases that are working.
    public static func functionalCases() -> [PortModeType] {
        return [.name, .raw, .pct, .si, .symbol, .mapping, .valueFormat]
    }
}

/// The value range of a port.
public struct PortValueRange {
    /// The minimum value.
    let min: Float32
    /// The maximum value.
    let max: Float32
}

/// The information about the port value format.
public struct PortValueFormat {
    /// The numbe of values per update.
    let datasetCount: UInt8
    /// The type of values.
    let datasetType: DatasetType
    /// The number of figures.
    let figureCount: UInt8
    /// The number of decimal places.
    let decimalCount: UInt8
}

/// The port mapping contained in the mode information.
public struct PortMapping {
    /// The mapping for the input modes
    let input: PortModeMapping
    /// The mapping for the ouptut modes.
    let output: PortModeMapping
}

/// An update message with some information on a port mode.
public enum PortModeUpdate {
    /// The name of the port.
    ///
    /// - parameter name The name.
    case name(name: String)
    /// The raw value range.
    ///
    /// - parameter range The value range.
    case raw(range: PortValueRange)
    /// The percent value range.
    ///
    /// - parameter range The value range.
    case pct(range: PortValueRange)
    /// The si value range.
    ///
    /// - parameter range The value range.
    case si(range: PortValueRange)
    /// The symbol of the value.
    ///
    /// - parameter name The symbol name.
    case symbol(name: String)
    /// The port mapping.
    ///
    /// - parameter mapping The port mapping.
    case mapping(mapping: PortMapping)
    /// The motor bias.
    ///
    /// - parameter bias The bias.
    case motorBias(bias: UInt8)
    /// The capability bits.
    ///
    /// - parameter capabilities The capabilites.
    case capabilityBits(capabilities: [UInt8])
    /// The value format.
    ///
    /// - parameter format The value format.
    case valueFormat(format: PortValueFormat)
    
    /// Decodes a port mode update message.
    ///
    /// - parameter type The port mode type.
    /// - parameter data The data with the values.
    /// - return The port mode update or nil, if the data is malformated
    public static func decode(type: PortModeType, data: [UInt8]) -> PortModeUpdate? {
        switch type {
        case .name:
            return .name(name: String(cString: data))
        case .raw:
            return .raw(range: PortValueRange(min: DatasetType.float32.decode(data: data, offset: 0) as! Float32, max: DatasetType.float32.decode(data: data, offset: 4) as! Float32))
        case .pct:
            return .pct(range: PortValueRange(min: DatasetType.float32.decode(data: data, offset: 0) as! Float32, max: DatasetType.float32.decode(data: data, offset: 4) as! Float32))
        case .si:
            return .si(range: PortValueRange(min: DatasetType.float32.decode(data: data, offset: 0) as! Float32, max: DatasetType.float32.decode(data: data, offset: 4) as! Float32))
        case .symbol:
            return .symbol(name: String(cString: data))
        case .mapping:
            return .mapping(mapping: PortMapping(input: PortModeMapping(value: data[0]), output: PortModeMapping(value: data[1])))
        case .motorBias:
            return .motorBias(bias: data[0])
        case .capabilityBits:
            return .capabilityBits(capabilities: data)
        case .valueFormat:
            if let format = DatasetType(rawValue: data[1]) {
                return .valueFormat(format: PortValueFormat(datasetCount: data[0], datasetType: format, figureCount: data[2], decimalCount: data[3]))
            }
        }
        return nil
    }
}

/// An enumeration with the dataset types.
public enum DatasetType: UInt8 {
    /// 1-byte Integer.
    case int8 = 0x00
    /// 2-byte Integer
    case int16 = 0x01
    /// 4-byte integer.
    case int32 = 0x02
    /// 4-byte floating point.
    case float32 = 0x03
    
    /// Returns the length of the dataset type in bytes.
    ///
    /// - returns The length in bytes.
    public func getLength() -> Int {
        switch self {
        case .int8:
            return 1
        case .int16:
            return 2
        case .int32, .float32:
            return 4
        }
    }

    /// Decoes a value of the dataset type by interpeting the data at the offset and returns
    /// the numeric value.
    ///
    /// - parameter data The data to read from.
    /// - parameter offset The offset into the data array to start from.
    /// - returns The value extracted from the data array at the offset.
    public func decode(data: [UInt8], offset: Int) -> any Numeric {
        switch self {
        case .int8:
            return Int8(bitPattern: data[offset])
        case .int16:
            return Int16(bitPattern: UInt16(data[offset + 1]) << 8 + UInt16(data[offset]))
        case .int32:
            return Int32(bitPattern: (UInt32(data[offset + 3]) << 24) | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 1]) << 8) | UInt32(data[offset + 0]))
        case .float32:
            let pattern = (UInt32(data[offset + 3]) << 24) | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 1]) << 8) | UInt32(data[offset + 0])
            return Float32(bitPattern: pattern)
        }
    }
}

/// A struct to represent the port mode mapping.
public struct PortModeMapping {
    /// A boolean to indicate whether mode supports null values.
    let supportsNull: Bool
    /// A boolean to indicate whether mode supports functional mapping 2.0..
    let supportsFunctionalMapping: Bool
    /// A boolean to indicate whether the value is absolute.
    let absolute: Bool
    /// A boolean to indicate whether the value is relative.
    let relative: Bool
    /// A boolean to indicate whether the value is discrete.
    let discrete: Bool
    
    /// Creates a port mode mapping by interpreting the value.
    ///
    /// - parameter value The value interpreted as bit vector.
    public init(value: UInt8) {
        supportsNull = value & 0x80 == 0x80
        supportsFunctionalMapping = value & 0x40 == 0x40
        absolute = value & 0x10 == 0x10
        relative = value & 0x08 == 0x08
        discrete = value & 0x04 == 0x04
    }
}

/// A struct to represent the port output state.
public struct PortOutputState {
    /// The port id.
    let portId: UInt8
    /// True if a command is in progress.
    let commandInProgess: Bool
    /// True if a command is completed.
    let commandCompleted: Bool
    /// True if a command is discarded.
    let commandDiscarded: Bool
    /// The port is idle..
    let idle: Bool
    /// The port is busy.
    let busy: Bool
    
    /// Initializes the port output state from the id and state.
    ///
    /// - parameter portId The port id.
    /// - parameter state The port output state.
    public init(portId: UInt8, state: UInt8) {
        self.portId = portId
        commandInProgess = state & 0x01 == 0x01
        commandCompleted = state & 0x02 == 0x02
        commandDiscarded = state & 0x04 == 0x04
        idle = state & 0x08 == 0x08
        busy = state & 0x10 == 0x10
    }    
}

/// An enumeration to connect or disconnect a virtual port.
public enum VirtualPortSetupRequest {
    /// Creates a port using the two specified ports.
    ///
    /// - parameter portId1 The first port.
    /// - parameter portId2 The second port.
    case connect(portId1: UInt8, portId2: UInt8)
    /// Removes a virtual port that has been created previously.
    ///
    /// - parameter virtualPortId The virtual port id.
    case disconnect(virtualPortId: UInt8)
    
    /// Encodes the setup request as a series of bytes.
    ///
    /// - returns The encoded request.
    public func encode() -> [UInt8] {
        switch self {
        case .connect(portId1: let portId1, portId2: let portId2):
            return [ 1, portId1, portId2 ]
        case .disconnect(virtualPortId: let portId):
            return [ 0, portId ]
        }
    }
}

/// An enumeration with operations to setup the input.
public enum PortInputSetupOperation: UInt8 {
    /// Set ModeAndDataSet combination(s)
    case set = 0x01
    /// Lock LPF2 Device for setup
    case lock = 0x02
    /// UnlockAndStartWithMultiUpdateEnabled
    case unlockEnabled = 0x03
    /// UnlockAndStartWithMultiUpdateDisabled
    case unlockDisabled = 0x04
    /// Reset Sensor
    case reset = 0x06
}

/// An enumeration with setup requests for a port input.
public enum PortInputSetupRequest {
    /// Sets the combination index and adataset modes.
    ///
    /// - parameter combinationIndex The index of the conbinations.
    /// - parameter modes The modes.
    /// - parameter datasets The dataseets.
    case set(combinationIndex: UInt8, modes: [UInt8], datasets: [UInt8])
    /// Locks the port for configuration.
    case lock
    /// Unlocks the port and enables the change notifications.
    case unlockEnabled
    /// Unlocks the port and disables the change notifications.
    case unlockDisabled
    /// Resets the port input configuration.
    case reset
    
    /// Encodes the request as a set of bytes.
    ///
    /// - returns The set of bytes.
    public func encode() -> [UInt8] {
        switch self {
        case .set(combinationIndex: let combinationIndex, modes: let modes, datasets: let datasets):
            let modeCount = min(modes.count, datasets.count)
            var result = [UInt8](repeating: 0, count: 2 + modeCount)
            result[0] = PortInputSetupOperation.set.rawValue
            result[1] = combinationIndex
            for i in 0..<modeCount {
                result[2 + i] = ((modes[i] << 4) & 0xF0) | (datasets[i] & 0x0F)
            }
            return result
        case .lock:
            return [ PortInputSetupOperation.lock.rawValue ]
        case .unlockEnabled:
            return [ PortInputSetupOperation.unlockEnabled.rawValue ]
        case .unlockDisabled:
            return [ PortInputSetupOperation.unlockDisabled.rawValue ]
        case .reset:
            return [ PortInputSetupOperation.reset.rawValue ]
        }
    }
}

/// An enumeration with falgs for output commands.
public enum PortOutputFlag: UInt8 {
    /// A flag to request the immediate execution.
    case immediate = 0x10
    /// A flag to request feedback on the execution.
    case feedback = 0x01
}

/// An enumeration with constants for output requests.
public enum PortOutputType: UInt8 {
    /// The write direct data mode.
    case writeDirectData = 0x50
    /// The wirte direct mode and data mode.
    case writeDirectModeData = 0x51
    /// Start power doual command.
    case startPowerDual = 0x02
    /// Set the acceleration time (profile).
    case setAccelerationTime = 0x05
    /// The the deceleration time (profile).
    case setDecelerationTime = 0x06
    /// Starts a particular speed.
    case startSpeed = 0x07
    /// Starts a particular speed dual
    case startSpeedDual = 0x08
    /// Starts a particular speed for a time.
    case startSpeedForTime = 0x09
    /// Starts a particular speed for a time dual.
    case startSpeedForTimeDual = 0x0A
    /// Starts a particular speed for a certain number of degrees.
    case startSpeedForDegrees = 0x0B
    /// Starts a particular speed for a certain number of degrees dual.
    case startSpeedForDegreesDual = 0x0C
    /// Moves to an absolute position.
    case gotoAbsolutePosition = 0x0D
    /// Moves to an absolute position dual
    case gotoAbsolutePositionDual = 0x0E
    /// Resets the encoder dual.
    case presetEncoderDual = 0x14
}

/// Flags to configure the speed commands with profile.
public enum ProfileFlag: UInt8 {
    /// Uses the acceleration profile.
    case useAcceleration = 0x01
    /// Uses the deceleration profile.
    case useDeceleration = 0x02
    
    /// Encodes the flags as UInt8.
    ///
    /// - parameter flags The flags to encode.
    public static func encode(flags: [ ProfileFlag ] ) -> UInt8 {
        var value: UInt8 = 0
        for f in flags {
            value |= f.rawValue
        }
        return value
    }
}

/// The orientation.
public enum Orientation: UInt8 {
    /// Bottom (Default/Normal)
    case bottom = 0
    /// Front
    case front = 1
    /// Back
    case back = 2
    /// Left
    case left = 3
    /// Right
    case right = 4
    /// Top
    case top = 5
    /// Use actual as Bottom reference.
    case actual = 6
}

/// The calibration for the tilt sensor.
public enum TiltCalibration: UInt8 {
    /// XY
    case lying = 1
    /// Z
    case standing = 2
}

/// An enumeration for port output requests.
public enum PortOutputRequest {
    /// Set the output power of a motor.
    ///
    /// - parameter mode The mode.
    /// - parameter power The power.
    case startPower(mode: UInt8, power: Power)
    /// Set the output power of two motors simultaneously.
    ///
    /// - parameter mode The mode.
    /// - parameter power1 The power of the first motor.
    /// - parameter power2 The power of the second motor.
    case startPowerDual(mode: UInt8, power1: Power, power2: Power)
    /// Sets an rgb preset.
    ///
    /// - parameter mode The mode.
    /// - parameter preset The color.
    case setRgbPreset(mode: UInt8, preset: UInt8)
    /// Sets an rgb light to a color value.
    ///
    /// - parameter mode The mode.
    /// - parameter red The red value.
    /// - parameter green The green value.
    /// - parameter blue The blue value.
    case setRgbColor(mode: UInt8, red: UInt8, green: UInt8, blue: UInt8)
    
    /// Sets the acceleration time to go from 0 to 100% for a particular
    /// profile.
    ///
    /// - parameter time The time from 0 to 100% (in milliseconds from 0 - 10000).
    /// - parameter profile The profile index.
    case setAccelerationTime(time: Int16, profile: UInt8)
    /// Sets the deceleration time to go from 100 to 0% for a particular
    /// profile.
    ///
    /// - parameter time The time from 100% to 0 (in milliseconds from 0 - 10000).
    /// - parameter profile The profile index.
    case setDecelerationTime(time: Int16, profile: UInt8)
    ///  Start or hold the motor(s) and keeping the speed without using power-levels greater than max power.
    ///
    ///  - parameter speed The speed to move to or hold.
    ///  - parameter maxPower The maximum power (0..100).
    ///  - parameter flags Whether to use the acceleration and deceleration profile.
    case startSpeed(speed: Speed, maxPower: Int8, flags: [ ProfileFlag ])
    ///  Start or hold the motor(s) and keeping the speed without using power-levels greater than max power.
    ///
    ///  - parameter speed1 The speed to move to or hold on the first motor.
    ///  - parameter speed2 The speed to move to or hold on the second motor.
    ///  - parameter maxPower The maximum power (0..100).
    ///  - parameter flags Whether to use the acceleration and deceleration profile.
    case startSpeedDual(speed1: Speed, speed2: Speed, maxPower: Int8, flags: [ ProfileFlag ])
    ///  Start the motor(s) for time ms. keeping a speed using a maximum power. After time stopping the output using the endState.
    ///
    /// - parameter time The time to run at the speed.
    /// - parameter speed The speed to run.
    /// - parameter maxPower The max power to use.
    /// - parameter endState The end state after the time.
    /// - parameter flags The profile flags to control the use of the acceleration and deceleration profile.
    case startSpeedForTime(time: Int16, speed: Speed, maxPower: Int8, endState: MotorState, flags: [ ProfileFlag])
    ///  Start the motor(s) for time ms. keeping a speed using a maximum power. After time stopping the output using the endState.
    ///
    /// - parameter time The time to run at the speed.
    /// - parameter speed1 The speed for the first motor.
    /// - parameter speed2 The speed for the second motor.
    /// - parameter maxPower The max power to use.
    /// - parameter endState The end state after the time.
    /// - parameter flags The profile flags to control the use of the acceleration and deceleration profile.
    case startSpeedForTimeDual(time: Int16, speed1: Speed, speed2: Speed, maxPower: Int8, endState: MotorState, flags: [ ProfileFlag])
    /// Starts the speed for a certain number of rotations with at most max power and then ending in the specified state.
    ///
    /// - parameter degrees The number of degrees to turn.
    /// - parameter speed The speed for the first motor.
    /// - parameter maxPower The max power to use.
    /// - parameter endState The end state after the time.
    /// - parameter flags The profile flags to control the use of the acceleration and deceleration profile.
    case startSpeedForDegrees(degrees: UInt32, speed: Speed, maxPower: Int8, endState: MotorState, flags: [ ProfileFlag ])
    /// Starts the speed for a certain number of rotations with at most max power and then ending in the specified state.
    ///
    /// - parameter degrees The number of degrees to turn.
    /// - parameter speed1 The speed for the first motor.
    /// - parameter speed2 The speed for the second motor.
    /// - parameter maxPower The max power to use.
    /// - parameter endState The end state after the time.
    /// - parameter flags The profile flags to control the use of the acceleration and deceleration profile.
    case startSpeedForDegreesDual(degrees: UInt32, speed1: Speed, speed2: Speed, maxPower: Int8, endState: MotorState, flags: [ ProfileFlag ])
    /// Start the motor with a speed  using a maximum power and moves to the absolute position. After position is reached the motor is stopped using the end state.
    ///
    /// - parameter position The absolute position.
    /// - parameter speed The speed.
    /// - parameter maxPower The max power to use.
    /// - parameter endState The end state after the time.
    /// - parameter flags The profile flags to control the use of the acceleration and deceleration profile.
    case gotoAbsolutePosition(position: Int32, speed: Speed, maxPower: Int8, endState: MotorState, flags: [ ProfileFlag ])
    /// Start the motor with a speed  using a maximum power and moves to the absolute position. After position is reached the motor is stopped using the end state.
    ///
    /// - parameter position1 The absolute position.
    /// - parameter position2 The absolute position.
    /// - parameter speed The speed.
    /// - parameter maxPower The max power to use.
    /// - parameter endState The end state after the time.
    /// - parameter flags The profile flags to control the use of the acceleration and deceleration profile.
    case gotoAbsolutePositionDual(position1: Int32, position2: Int32, speed: Speed, maxPower: Int8, endState: MotorState, flags: [ ProfileFlag ])
    /// Preset the encoder of the motor to Position. A 0 (zero) value equals reset.
    ///
    /// - parameter mode The mode.
    /// - parameter position The position to set.
    case presetEncoder(mode: UInt8, position: Int32)
    /// Presets only the individual encoders of the synchronized motors to the positions.
    /// The synchronized virtual encoder is not affected. A value of 0 (zero) equals RESET.
    ///
    /// - parameter position1 The position for the first encoder.
    /// - parameter position2 The position for the second encoder.
    case presetEncoderDual(position1: Int32, position2: Int32)
    /// (P)Resets the impact counts.
    ///
    /// - parameter preset The value to set to (0 for reset).
    case tiltImpactPreset(preset: Int32)
    /// Set the default bottom side (orientation).
    ///
    ///  - parameter orientation The orientation to set.
    case tiltConfigOrientation(orientation: Orientation)
    ///  Sets the Impact size for a BUMP.
    ///
    /// - parameter impactThreshold Sets the minimum Holdoff time between individual impacts (Bumps).
    /// - parameter bumpHoldoff  The HoldOff can be set between 10 ms. and 1.27 second
    case tiltConfigImpact(impactThreshold: Int8, bumpHoldoff: Int8)
    /// Tells the orientation set physically by the montage automat.
    ///
    /// - parameter calibration The orientation of the sensor.
    case tiltFactoryCalibration(calibration: TiltCalibration)
    /// Resets or zerosets the H/W component attached to the port.
    case zeroSetHardware
    
    /// Encodes the output request as a series of bytes.
    ///
    /// - returns The encoded request.
    public func encode() -> [UInt8] {
        switch self {
        case .startPower(mode: let mode, power: let power):
            return [ PortOutputType.writeDirectModeData.rawValue, mode, power.encode() ]
        case .startPowerDual(mode: let mode, power1: let power1, power2: let power2):
            return [ PortOutputType.startPowerDual.rawValue, mode, power1.encode(), power2.encode()]
        case .setRgbPreset(mode: let mode, preset: let preset):
            return [ PortOutputType.writeDirectModeData.rawValue, mode, preset]
        case .setRgbColor(mode: let mode, red: let red, green: let green, blue: let blue):
            return [ PortOutputType.writeDirectModeData.rawValue, mode, red, green, blue ]
        case .setAccelerationTime(time: let time, profile: let profile):
            return [ PortOutputType.setAccelerationTime.rawValue, UInt8(time & 0xff), UInt8((time >> 8) & 0xff), profile ]
        case .setDecelerationTime(time: let time, profile: let profile):
            return [ PortOutputType.setDecelerationTime.rawValue, UInt8(time & 0xff), UInt8((time >> 8) & 0xff), profile ]
        case .startSpeed(speed: let speed, maxPower: let maxPower, flags: let flags):
            return [ PortOutputType.startSpeed.rawValue, speed.encode(), UInt8(bitPattern: maxPower), ProfileFlag.encode(flags: flags) ]
        case .startSpeedDual(speed1: let speed1, speed2: let speed2, maxPower: let maxPower, flags: let flags):
            return [ PortOutputType.startSpeedDual.rawValue, speed1.encode(), speed2.encode(), UInt8(bitPattern: maxPower), ProfileFlag.encode(flags: flags) ]
        case .startSpeedForTime(time: let time, speed: let speed, maxPower: let maxPower, endState: let endState, flags: let flags):
            return [ PortOutputType.startSpeedForTime.rawValue, UInt8(time & 0xff), UInt8((time >> 8) & 0xff), speed.encode(), UInt8(bitPattern: maxPower), endState.rawValue, ProfileFlag.encode(flags: flags)]
        case .startSpeedForTimeDual(time: let time, speed1: let speed1, speed2: let speed2, maxPower: let maxPower, endState: let endState, flags: let flags):
            return [ PortOutputType.startSpeedForTimeDual.rawValue, UInt8(time & 0xff), UInt8((time >> 8) & 0xff), speed1.encode(), speed2.encode(), UInt8(bitPattern: maxPower), endState.rawValue, ProfileFlag.encode(flags: flags)]
        case .startSpeedForDegrees(degrees: let degrees, speed: let speed, maxPower: let maxPower, endState: let endState, flags: let flags):
            return [ PortOutputType.startSpeedForDegrees.rawValue, UInt8(degrees & 0xff), UInt8((degrees >> 8) & 0xff), UInt8((degrees >> 16) & 0xff), UInt8((degrees >> 24) & 0xff), speed.encode(), UInt8(bitPattern: maxPower), endState.rawValue, ProfileFlag.encode(flags: flags) ]
        case .startSpeedForDegreesDual(degrees: let degrees, speed1: let speed1, speed2: let speed2, maxPower: let maxPower, endState: let endState, flags: let flags):
            return [ PortOutputType.startSpeedForDegreesDual.rawValue, UInt8(degrees & 0xff), UInt8((degrees >> 8) & 0xff), UInt8((degrees >> 16) & 0xff), UInt8((degrees >> 24) & 0xff), speed1.encode(), speed2.encode(), UInt8(bitPattern: maxPower), endState.rawValue, ProfileFlag.encode(flags: flags) ]
        case .gotoAbsolutePosition(position: let position, speed: let speed, maxPower: let maxPower, endState: let endState, flags: let flags):
            return [ PortOutputType.gotoAbsolutePosition.rawValue, UInt8(position & 0xff), UInt8((position >> 8) & 0xff), UInt8((position >> 16) & 0xff), UInt8((position >> 24) & 0xff), speed.encode(), UInt8(bitPattern: maxPower), endState.rawValue, ProfileFlag.encode(flags: flags) ]
        case .gotoAbsolutePositionDual(position1: let position1, position2: let position2, speed: let speed, maxPower: let maxPower, endState: let endState, flags: let flags):
            return [ PortOutputType.gotoAbsolutePositionDual.rawValue, UInt8(position1 & 0xff), UInt8((position1 >> 8) & 0xff), UInt8((position1 >> 16) & 0xff), UInt8((position1 >> 24) & 0xff), UInt8(position2 & 0xff), UInt8((position2 >> 8) & 0xff), UInt8((position2 >> 16) & 0xff), UInt8((position2 >> 24) & 0xff), speed.encode(), UInt8(bitPattern: maxPower), endState.rawValue, ProfileFlag.encode(flags: flags) ]
        case .presetEncoder(mode: let mode, position: let position):
            return [ PortOutputType.writeDirectModeData.rawValue, mode, UInt8(position & 0xff), UInt8((position >> 8) & 0xff), UInt8((position >> 16) & 0xff), UInt8((position >> 24) & 0xff) ]
        case .presetEncoderDual(position1: let position1, position2: let position2):
            return [ PortOutputType.presetEncoderDual.rawValue, UInt8(position1 & 0xff), UInt8((position1 >> 8) & 0xff), UInt8((position1 >> 16) & 0xff), UInt8((position1 >> 24) & 0xff), UInt8(position2 & 0xff), UInt8((position2 >> 8) & 0xff), UInt8((position2 >> 16) & 0xff), UInt8((position2 >> 24) & 0xff) ]
        case .tiltImpactPreset(preset: let preset):
            return [ PortOutputType.writeDirectModeData.rawValue, 3, UInt8(preset & 0xff), UInt8((preset >> 8) & 0xff), UInt8((preset >> 16) & 0xff), UInt8((preset >> 24) & 0xff) ]
        case .tiltConfigOrientation(orientation: let orientation):
            return [ PortOutputType.writeDirectModeData.rawValue, 5, orientation.rawValue ]
        case .tiltConfigImpact(impactThreshold: let impact, bumpHoldoff: let bump):
            return [ PortOutputType.writeDirectModeData.rawValue, 6, UInt8(bitPattern: impact), UInt8(bitPattern: bump) ]
        case .tiltFactoryCalibration(calibration: let calibration):
            var result: [UInt8] = [ PortOutputType.writeDirectData.rawValue, calibration.rawValue ]
            let token = Array("Calib-Sensor".utf8)
            var chksum = 0xff ^ calibration.rawValue
            for value in token {
                result.append(value)
                chksum = chksum ^ value
            }
            result.append(chksum)
            return result
        case .zeroSetHardware:
            var result = [ PortOutputType.writeDirectData.rawValue, 0x11 ]
            result.append(0xff ^ 0x11)
            return result
        }
    }
}

/// Represents an end state of a motor.
public enum MotorState: UInt8 {
    /// Float motor.
    case float = 0
    /// Brake motor.
    case brake = 127
    /// Hold motor.
    case hold = 126
}


/// Represents a speed value.
public enum Speed {
    /// clockwise rotation (from 1-100)
    case cw(value: UInt8)
    /// counter clockwise rotation (from 1-100)
    case ccw(value: UInt8)
    /// hold motor (0)
    case hold
    
    /// Creates a speed value from an integer.
    ///
    /// - parameter value The value.
    /// - returns The parsed power.
    public static func fromInt(value: Int8) -> Speed? {
        if value == 0 {
            return hold
        } else if value < 0 && value >= -100 {
            return ccw(value: UInt8(-value))
        } else if value > 0 && value <= 100 {
            return cw(value: UInt8(value))
        } else {
            return nil
        }
    }
    
    /// Converts the speed to an int.
    ///
    /// - returns The int.
    public func toInt() -> Int8 {
        switch self {
        case .hold:
            return 0
        case .cw(value: let value):
            return Int8(max(1, min(100, value)))
        case .ccw(value: let value):
            return -Int8(max(1, min(100, value)))
        }
    }
    
    /// Encoeds the speed as an uint value.
    ///
    /// - returns The uint value representing the speed.
    public func encode() -> UInt8 {
        return UInt8(bitPattern: toInt())
    }
}


/// Represents a power value.
public enum Power {
    /// clockwise rotation (from 1-100)
    case cw(value: UInt8)
    /// counter clockwise rotation (from 1-100)
    case ccw(value: UInt8)
    /// floating motor (0)
    case float
    /// brake (127)
    case brake
    
    /// Creates a power value from an integer.
    ///
    /// - parameter value The value.
    /// - returns The parsed power.
    public static func fromInt(value: Int8) -> Power? {
        if value == 0 {
            return float
        } else if value == 127 {
            return brake
        } else if value < 0 && value >= -100 {
            return ccw(value: UInt8(-value))
        } else if value > 0 && value <= 100 {
            return cw(value: UInt8(value))
        } else {
            return nil
        }
    }
    
    /// Converts the power to an int.
    ///
    /// - returns The int.
    public func toInt() -> Int8 {
        switch self {
        case .brake:
            return 127
        case .float:
            return 0
        case .cw(value: let value):
            return Int8(max(1, min(100, value)))
        case .ccw(value: let value):
            return -Int8(max(1, min(100, value)))
        }
    }
    
    /// Encoeds the power as an uint value.
    ///
    /// - returns The uint value representing the power.
    public func encode() -> UInt8 {
        return UInt8(bitPattern: toInt())
    }
}
