//
//  Port.swift - Structs and classes to manage port
//      information, ports and port values.
//
//  Created by Marcus Handte on 28.03.23.
//

import Foundation


/// Represents some piece of port information.
public struct PortInformation {
    /// The port generates values (input).
    let input: Bool
    /// The port receives values (output).
    let output: Bool
    /// The port supports multiple mode combinations.
    let combinable: Bool
    /// The port can be synchronized with another port.
    let synchronizable: Bool
    /// The supported input modes.
    let inputModes: [UInt8]
    /// The supported output modes.
    let outputModes: [UInt8]
    /// The mode combinatiosns.
    var modeCombinations: [[UInt8]]?
    
    
    /// Checks if the set of ports is supported by comparing
    /// the port mode ids with the index port info.
    ///
    /// - parameter mode The port combination to check.
    /// - returns The mode index or -1, if not found.
    func findModeIndex(mode: [UInt8]) -> Int {
        guard combinable else {
            return -1
        }
        if let modes = modeCombinations {
            for (i, combination) in modes.enumerated() {
                if matchesMode(mode: mode, combination: combination) {
                    // the mode is starting from 1 and not 0
                    return i + 1
                }
            }
        }
        // Combination index 0 is used to signal a
        // subscription to all port values. This seems to be
        // an implied combination for all sensor that support
        // combined subscriptions.
        return 0
    }
    
    /// Checks if the mode matches the mode combination.
    ///
    /// - parameter mode The mode to check.
    /// - parameter combination The combination to check.
    /// - returns True if the mode matches the combination, false otherwise.
    func matchesMode(mode: [UInt8], combination: [UInt8]) -> Bool {
        if mode.count != combination.count {
            return false;
        }
        for m in mode {
            if !combination.contains(m) {
                return false
            }
        }
        return true
    }
    
    
}

/// The information about a port mode.
public struct PortModeInformation {
    /// The mode id.
    let mode: UInt8
    /// The mode name.
    var name: String? = nil
    /// The raw range.
    var rawRange: PortValueRange? = nil
    /// The percent range.
    var percentRange: PortValueRange? = nil
    /// The si range.
    var siRange: PortValueRange? = nil
    /// The symbol.
    var symbol: String? = nil
    /// The port mapping.
    var mapping: PortMapping? = nil
    /// The motor bias.
    var motorBias: UInt8? = nil
    /// The capability bits.
    var capabilites: [UInt8]? = nil
    /// The port value format.
    var format: PortValueFormat? = nil
}

/// The state of the port.
public enum PortStatus {
    /// The port has been detected but the configuration
    /// of the port has not been retrieved yet.
    case initializing
    /// The retrieval of the port's configuration has failed.
    case failure
    /// The port has been detected and its configuration
    /// has been retrieved completely.
    case initialized
}

/// The base class for a port.
public class Port: NSObject {
    
    /// The hub that spawned the port.
    public weak var hub: Hub?
    /// The port id.
    public let portId: UInt8
    /// The device id represented by the port.
    public let deviceId: UInt16
    /// Information about the port.
    public var information: PortInformation?
    /// Information about the modes of the port.
    public var modeInformation: [UInt8:PortModeInformation] = [:]

    /// The number of running requests.
    var initRequests = 0
    /// The (known) values of the port.
    internal(set) public var portValues: [PortValue] = []
    /// The current subscrptions of the port.
    internal(set) public var subscription: [PortValueSubscription] = []

    /// Returns a debug description with the port id and the port information and modeInformation.
    public override var debugDescription: String {
        let portType = String(describing: type(of: self))
        var result = "\(portType): \(portId) (\(deviceId)))"
        if let information {
            result += " \(information)"
            for mode in information.inputModes {
                if let modeInfo = modeInformation[mode] {
                    result += " \(modeInfo)"
                }
            }
        }
        return result
    }
    
    /// A flag to indicate whether the initialization failed.
    internal(set) public var status = PortStatus.initializing
    /// A delegate to detect when the port can be used.
    var delegate: ((Port)->Void)?
    
    /// Creates a new port with the id.
    ///
    /// - parameter hub The hub to which the port is attached.
    /// - parameter portId The id id of the port.
    /// - parameter deviceId The device type id.
    public init(hub: Hub, portId: UInt8, deviceId: UInt16) {
        self.portId = portId
        self.deviceId = deviceId
        self.hub = hub
        super.init()
    }
    
    
    /// Called by the hub to set the value.
    ///
    /// - parameter data The data representing the value.
    func setValue(data: [UInt8]) {
        guard subscription.count == 1 else {
            return
        }
        if let s = subscription.first, let info = modeInformation[s.mode], let format = info.format {
            let count = Int(format.datasetCount)
            let length = format.datasetType.getLength()
            var values: [any Numeric] = []
            for i in 0..<count {
                values.append(format.datasetType.decode(data: data, offset: i * length))
            }
            for value in portValues {
                if (value.mode == s.mode) {
                    value.setValue(value: values, decimals: Int(format.decimalCount))
                }
            }
        }
    }
    
    /// Sets the multi mode input format.
    ///
    /// - parameter modes The modes.
    /// - parameter data The data describing the format.
    func setValues(modes: [UInt8], data: [UInt8]) {
        var contents: [PortValueSubscription] = []
        for mode in modes {
            if mode < subscription.count {
                contents.append(subscription[Int(mode)])
            } else {
                // invalid packet
                return
            }
        }
        var total = 0
        for s in contents {
            if let info = modeInformation[s.mode], let format = info.format {
                let count = Int(format.datasetCount)
                let length = format.datasetType.getLength()
                total += count * length
            } else {
                // invalid packet
                return
            }
        }
        guard total == data.count else {
            return
        }
        var dataOffset = 0
        for s in contents {
            if let info = modeInformation[s.mode], let format = info.format {
                let count = Int(format.datasetCount)
                let length = format.datasetType.getLength()
                var values: [any Numeric] = []
                for _ in 0..<count {
                    values.append(format.datasetType.decode(data: data, offset: dataOffset))
                    dataOffset += length
                }
                for value in portValues {
                    if (value.mode == s.mode) {
                        value.setValue(value: values, decimals: Int(format.decimalCount))
                    }
                }
            } else {
                // if the mode info is missing, we do not know how
                // long the data is, so we cannt decode the rest
                return
            }
        }
    }
        
    /// Called by the hub to initialize the port. This implementation will
    /// request the port info and port mode info and then signal completion
    /// via the delegate.
    func initialize() {
        let handler: (ResponseBody?, TransmissionError?)->Void = { body, error in
            self.initRequests -= 1
            if let error {
                self.status = .failure
                if let h = self.hub, let m = h.manager {
                    m.hubError(hub: h, error: error)
                }
            }
            if self.initRequests == 0 && self.status == .initializing {
                self.signalInitialized()
            }
        }
        if let hub {
            hub.enqueueMessage(body: .portInformation(portId: portId, request: .modeInfo)) {
                body, error in
                if let error {
                    self.status = .failure
                    if let h = self.hub, let m = h.manager {
                        m.hubError(hub: h, error: error)
                    }
                } else {
                    if let information = self.information {
                        if information.modeCombinations == nil {
                            self.initRequests += 1
                            hub.enqueueMessage(body: .portInformation(portId: self.portId, request: .modeCombinations), handler: handler)
                        }
                        for mode in information.inputModes {
                            if self.modeInformation[mode] == nil {
                                self.modeInformation[mode] = PortModeInformation(mode: mode)
                                for request in PortModeType.functionalCases() {
                                    self.initRequests += 1
                                    hub.enqueueMessage(body: .portModeInformation(portId: self.portId, mode: mode, request: request), handler: handler)
                                }
                            }
                        }
                    }
                    if self.initRequests == 0 && self.status == .initializing {
                        self.signalInitialized()
                    }
                }
            }
        }
    }
    
    /// Called when the port has been initialized. This will
    /// set the status to initialized and inform the delegate.
    ///
    /// - parameter status The port status.
    func signalInitialized() {
        self.status = .initialized
        if let delegate {
            delegate(self)
            self.delegate = nil
        }
    }
    
    /// Subscribes multiple values at once. Note that for this to work,
    /// the port info must indicate suport for combined modes and there
    /// must be a possible mode combination that matches the port values.
    /// Note that only the first delta seems to be considered when deciding
    /// whether to send an updated sample. Thus, it makes sense to order
    /// the port values in such a way that the first value updates most frequently.
    ///
    /// - parameters values The port values to subscribe.
    /// - parameters datasets The datasets of the values.
    /// - parameters deltas The deltas for the ports.
    public func subscribeValues(values: [PortValue], datasets: [UInt8], deltas: [UInt32]) {
        guard values.count > 1 && values.count == deltas.count && values.count == datasets.count else {
            return
        }
        if let hub, let info = information {
            let modeIds = values.map { $0.mode }
            let modeIndex = info.findModeIndex(mode: modeIds)
            guard modeIndex != -1 else {
                return
            }
            self.subscription = []
            hub.enqueueMessage(body: .portInputFormatSetupCombined(portId: portId, request: .lock)) {
                _, error in
                if let error, let m = hub.manager {
                    m.hubError(hub: hub, error: error)
                }
            }
            for (mode, delta) in zip(modeIds, deltas) {
                hub.enqueueMessage(body: .portInputFormatSetupSingle(portId: self.portId, mode: mode, delta: delta, notify: true)) {
                    result, error in
                    if case .portInputFormatSingle(portId: _, mode: let resMode, delta: let resDelta, notify: let resNotify) = result {
                        self.subscription.append(PortValueSubscription(mode: resMode, delta: resDelta, notify: resNotify))
                    } else if let error, let manager = hub.manager {
                        manager.queue.async {
                            manager.hubError(hub: hub, error: error)
                        }
                    }
                }
            }
            hub.enqueueMessage(body: .portInputFormatSetupCombined(portId: self.portId, request: .set(combinationIndex: UInt8(modeIndex), modes: modeIds, datasets: datasets))) { _, error in
                if let error, let manager = hub.manager {
                    manager.queue.async {
                        manager.hubError(hub: hub, error: error)
                    }
                }
            }
            hub.enqueueMessage(body: .portInputFormatSetupCombined(portId: self.portId, request: .unlockEnabled)) {
                result, error in
                if let error, let manager = hub.manager {
                    manager.queue.async {
                        manager.hubError(hub: hub, error: error)
                    }
                }
            }
        }
    }
    
    
    /// Sends a port output command. If a handler is provided, the output command will be
    /// requested to generate feedback upon completion. If the immediate flag is set, the
    /// command will be requested to execute immediately.
    ///
    /// - parameter request The port output command.
    /// - parameter immediate A flag to request the immediate (unqueued) operation.
    /// - parameter handler An optional handler to request and receive an acknowledgement.
    public func sendOutputCommand(request: PortOutputRequest, immediate: Bool, handler: ((ResponseBody)->Void)?) {
        if let hub {
            var flags: [PortOutputFlag] = []
            if immediate {
                flags.append(.immediate)
            }
            if handler != nil {
                flags.append(.feedback)
            }
            hub.enqueueMessage(body: .portOutputCommand(portId: portId, flags: flags, request: request)) {
                response, error in
                if let error {
                    hub.manager?.hubError(hub: hub, error: error)
                } else if let response, let handler {
                    handler(response)
                }
            }
        }
    }
}


/// Represents a virtual port that combines two ports in order to enable synchronized control.
public class VirtualPort: Port {

    /// The first port.
    public let port1: Port
    /// The second port.
    public let port2: Port
    
    /// Creates a new port for the hub with the specified id combining two ports.
    ///
    /// - parameter hub The hub.
    /// - parameter portId The port id of the virtual port.
    /// - parameter deviceId The device type id.
    /// - parameter port1 The first port.
    /// - parameter port2 The second port.
    public init(hub: Hub, portId: UInt8, deviceId: UInt16, port1: Port, port2: Port) {
        self.port1 = port1
        self.port2 = port2
        super.init(hub: hub, portId: portId, deviceId: deviceId)
    }
}


/// A port that represents a hardware device.
public class HardwarePort: Port {
    /// The hardware revision of the device.
    public let hardwareRevision: Version
    /// The software version of the device.
    public let softwareRevision: Version
    
    /// Creates the hardware port.
    ///
    /// - parameter hub The hub.
    /// - parameter portId The port id.
    /// - parameter deviceId The device id.
    /// - parameter hardwareRevision The hardware revision.
    /// - parameter softwareRevision The software version.
    public init(hub: Hub, portId: UInt8, deviceId: UInt16, hardwareRevision: Version, softwareRevision: Version) {
        self.hardwareRevision = hardwareRevision
        self.softwareRevision = softwareRevision
        super.init(hub: hub, portId: portId, deviceId: deviceId)
    }
    
}

/// Base class for a value made available by a port.
public class PortValue {
    
    /// The mode that publishes the value.
    let mode: UInt8
    /// A reference to the port that hosts the value.
    weak var port: Port?
    
    /// Creates a new value with the specified mode.
    ///
    /// - parameter mode The mode publishing the value.
    public init(mode: UInt8) {
        self.mode = mode
    }
    
    /// Updates the value of the port value.
    ///
    /// - parameter value The value to set.
    /// - parameter decimals The number of decimals.
    func setValue(value: [any Numeric], decimals: Int) { 
        if let port, port.subscription.count == 1, let s = port.subscription.first {
            if !s.notify {
                port.subscription = []
            }
        }
    }
    
    /// Requests an update for the value.
    public func request() {
        if let port, let hub = port.hub {            
           hub.enqueueMessage(body: .portInputFormatSetupSingle(portId: port.portId, mode: mode, delta: 1, notify: false)) {
                result, error in
                if case .portInputFormatSingle(portId: _, mode: let resMode, delta: let resDelta, notify: let resNotify) = result {
                   port.subscription = [ PortValueSubscription(mode: resMode, delta: resDelta, notify: resNotify) ]
                }
                if let error, let manager = hub.manager {
                    manager.queue.async {
                        manager.hubError(hub: hub, error: error)
                    }
                }
            }
            hub.enqueueMessage(body: .portInformation(portId: port.portId, request: .portValue)) {
                _, error in
                if let error, let manager = hub.manager {
                    manager.queue.async {
                        manager.hubError(hub: hub, error: error)
                    }
                }
            }
        }
    }
    
    /// Changes the subscription for the port value.
    ///
    /// - parameter delta The delta interval to suppress updates.
    /// - parameter notify True to publish new values, false to remove the subscription.
    public func subscribe(delta: UInt32, notify: Bool) {
        if let port, let hub = port.hub {
            hub.enqueueMessage(body: .portInputFormatSetupSingle(portId: port.portId, mode: mode, delta: delta, notify: notify)) {
                result, error in
                if case .portInputFormatSingle(portId: _, mode: let resMode, delta: let resDelta, notify: let resNotify) = result {
                    if resNotify {
                        port.subscription = [ PortValueSubscription(mode: resMode, delta: resDelta, notify: resNotify) ]
                    } else {
                        port.subscription = [ ]
                    }
            
                }
                if let error, let manager = hub.manager {
                    manager.queue.async {
                        manager.hubError(hub: hub, error: error)
                    }
                }
            }
        }
    }
    
}

/// A port value that provides a vector of floats.
public class FloatPortValue: PortValue {
    
    /// The value of the port.
    public var value: [Float]?
    /// An optional delegate to track changes.
    public var delegate: ((FloatPortValue, [Float])->Void)?
    
    /// Called by the port to set the value.
    ///
    /// - parameter value The value vector.
    /// - parameter decimals the number of decimals.
    override func setValue(value: [any Numeric], decimals: Int) {
        super.setValue(value: value, decimals: decimals)
        var val: [Float] = []
        for v in value {
            if let f = v as? Float32 {
                val.append(Float(f) / powf(10, Float(decimals)))
            } else if let f = v as? Int16 {
                val.append(Float(f) / powf(10, Float(decimals)))
            } else if let f = v as? Int32 {
                val.append(Float(f) / powf(10, Float(decimals)))
            } else if let f = v as? Int8 {
                val.append(Float(f) / powf(10, Float(decimals)))
            }
        }
        self.value = val
        if let delegate {
            delegate(self, val)
        }
    }
}

/// A port value that provides a vector of ints.
public class IntPortValue: PortValue {
    /// The port value.
    public var value: [Int]?
    /// An optional delegate to track changes.
    public var delegate: ((IntPortValue, [Int])->Void)?
    
    /// Called by the port to set the value.
    ///
    /// - parameter value The value vector.
    /// - parameter decimals the number of decimals.
    override func setValue(value: [any Numeric], decimals: Int) {
        super.setValue(value: value, decimals: decimals)
        guard decimals == 0 else {
            return
        }
        var val: [Int] = []
        for v in value {
            if let f = v as? Int {
                val.append(Int(f))
            } else if let f = v as? Int16 {
                val.append(Int(f))
            } else if let f = v as? Int32 {
                val.append(Int(f))
            } else if let f = v as? Int8 {
                val.append(Int(f))
            }
        }
        self.value = val
        if let delegate {
            delegate(self, val)
        }
    }
}

/// Represents the current subscription.
public struct PortValueSubscription {
    /// The subscribed mode.
    let mode: UInt8
    /// The delta value.
    let delta: UInt32
    /// The auto notification state.
    let notify: Bool
}


/// A  port that measures the voltage.
public class VoltagePort: HardwarePort {
    /// VLT L  (mV)
    public let voltageLong = IntPortValue(mode: 0)
    /// VLT S (mV)
    public let voltageShort = IntPortValue(mode: 1)
    
    /// Creates the  port.
    ///
    /// - parameter hub The hub.
    /// - parameter portId The port id.
    /// - parameter hardwareRevision The hardware revision.
    /// - parameter softwareRevision The software version.
    public init(hub: Hub, portId: UInt8, hardwareRevision: Version, softwareRevision: Version) {
        super.init(hub: hub, portId: portId, deviceId: DeviceType.voltageSensor.rawValue, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
        voltageLong.port = self
        voltageShort.port = self
        portValues = [ voltageLong, voltageShort ]
    }
    
}

/// A port that measures the current.
public class CurrentPort: HardwarePort {
    /// CUR L (mA)
    public let currentLong = IntPortValue(mode: 0)
    /// CUR S (mA)
    public let currentShort = IntPortValue(mode: 1)

    /// Creates the  port.
    ///
    /// - parameter hub The hub.
    /// - parameter portId The port id.
    /// - parameter hardwareRevision The hardware revision.
    /// - parameter softwareRevision The software version.
    public init(hub: Hub, portId: UInt8, hardwareRevision: Version, softwareRevision: Version) {
        super.init(hub: hub, portId: portId, deviceId: DeviceType.currentSensor.rawValue, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
        currentLong.port = self
        currentShort.port = self
        portValues = [ currentLong, currentShort ]
    }
    
}

/// A port that measures temperature.
public class TemperaturePort: HardwarePort {
    // TEMP (DEG)
    public let temperature: FloatPortValue = FloatPortValue(mode: 0)
    
    /// Creates the  port.
    ///
    /// - parameter hub The hub.
    /// - parameter portId The port id.
    /// - parameter hardwareRevision The hardware revision.
    /// - parameter softwareRevision The software version.
    public init(hub: Hub, portId: UInt8, hardwareRevision: Version, softwareRevision: Version) {
        super.init(hub: hub, portId: portId, deviceId: DeviceType.temperatureSensor.rawValue, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
        temperature.port = self
        portValues = [ temperature ]
    }
}

/// A port representing a gyroscope.
public class GyroPort: HardwarePort {
    // ROT (DPS)
    public let rotation = IntPortValue(mode: 0)
    
    /// Creates the  port.
    ///
    /// - parameter hub The hub.
    /// - parameter portId The port id.
    /// - parameter hardwareRevision The hardware revision.
    /// - parameter softwareRevision The software version.
    public init(hub: Hub, portId: UInt8, hardwareRevision: Version, softwareRevision: Version) {
        super.init(hub: hub, portId: portId, deviceId: DeviceType.gyroSensor.rawValue, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
        rotation.port = self
        portValues = [ rotation ]
    }
}

/// A port representing an accelerometer.
public class AccelerationPort: HardwarePort {
    // GRV (mG)
    public let gravity = IntPortValue(mode: 0)
    // CAL (-)
    public let calibration = IntPortValue(mode: 1)
    
    /// Creates the  port.
    ///
    /// - parameter hub The hub.
    /// - parameter portId The port id.
    /// - parameter hardwareRevision The hardware revision.
    /// - parameter softwareRevision The software version.
    public init(hub: Hub, portId: UInt8, hardwareRevision: Version, softwareRevision: Version) {
        super.init(hub: hub, portId: portId, deviceId: DeviceType.accelerationSensor.rawValue, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
        gravity.port = self
        calibration.port = self
        portValues = [ gravity, calibration ]
    }
}

/// A port representing a linear motor.
public class LinearMotorPort:  HardwarePort {
    // speed (PCT)
    public let speed = IntPortValue(mode: 1)
    // pos (DEG)
    public let position = IntPortValue(mode: 2)
    // apos (DEG)
    public let angle = IntPortValue(mode: 3)
    // load (pct)
    public let load = IntPortValue(mode: 4)

    /// Creates the  port.
    ///
    /// - parameter hub The hub.
    /// - parameter portId The port id.
    /// - parameter hardwareRevision The hardware revision.
    /// - parameter softwareRevision The software version.
    public init(hub: Hub, portId: UInt8, hardwareRevision: Version, softwareRevision: Version) {
        super.init(hub: hub, portId: portId, deviceId: DeviceType.linearMotor.rawValue, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
        speed.port = self
        position.port = self
        angle.port = self
        load.port = self
        portValues = [ speed, position, angle, load]
    }
    
    /// Subscribes all port values in a combined subscription using the specified delta.
    ///
    /// - parameter delta The delta.
    public func subscribeAll(delta: UInt32) {
        let deltas = [UInt32](repeating: delta, count: 4)
        let datasets = [UInt8].init(repeating: 0, count: 4)
        super.subscribeValues(values: [ angle, position, speed, load ], datasets: datasets, deltas: deltas)
    }
    
    
    /// Set the output power of a motor.
    ///
    /// - parameter mode The mode.
    /// - parameter power The power.
    public func startPower(mode: UInt8, power: Power) {
        sendOutputCommand(request: .startPower(mode: mode, power: power), immediate: false, handler: nil)
    }

    /// Sets the acceleration time to go from 0 to 100% for a particular profile.
    ///
    /// - parameter time The time from 0 to 100% (in milliseconds from 0 - 10000).
    /// - parameter profile The profile index.
    public func setAccelerationTime(time: Int16, profile: UInt8) {
        sendOutputCommand(request: .setAccelerationTime(time: time, profile: profile), immediate: false, handler: nil)
    }
    
    /// Sets the deceleration time to go from 100 to 0% for a particular profile.
    ///
    /// - parameter time The time from 100% to 0 (in milliseconds from 0 - 10000).
    /// - parameter profile The profile index.
    public func setDecelerationTime(time: Int16, profile: UInt8) {
        sendOutputCommand(request: .setDecelerationTime(time: time, profile: profile), immediate: false, handler: nil)
    }
    
    ///  Start or hold the motor(s) and keeping the speed without using power-levels greater than max power.
    ///
    ///  - parameter speed The speed to move to or hold.
    ///  - parameter maxPower The maximum power (0..100).
    ///  - parameter flags Whether to use the acceleration and deceleration profile.
    public func startSpeed(speed: Speed, maxPower: Int8, flags: [ ProfileFlag ]) {
        sendOutputCommand(request: .startSpeed(speed: speed, maxPower: maxPower, flags: flags), immediate: false, handler: nil)
    }
    
    ///  Start the motor(s) for time ms. keeping a speed using a maximum power. After time stopping the output using the endState.
    ///
    /// - parameter time The time to run at the speed.
    /// - parameter speed The speed to run.
    /// - parameter maxPower The max power to use.
    /// - parameter endState The end state after the time.
    /// - parameter flags The profile flags to control the use of the acceleration and deceleration profile.
    public func startSpeedForTime(time: Int16, speed: Speed, maxPower: Int8, endState: MotorState, flags: [ ProfileFlag]) {
        sendOutputCommand(request: .startSpeedForTime(time: time, speed: speed, maxPower: maxPower, endState: endState, flags: flags), immediate: false, handler: nil)
    }

    /// Starts the speed for a certain number of rotations with at most max power and then ending in the specified state.
    ///
    /// - parameter degrees The number of degrees to turn.
    /// - parameter speed The speed for the first motor.
    /// - parameter maxPower The max power to use.
    /// - parameter endState The end state after the time.
    /// - parameter flags The profile flags to control the use of the acceleration and deceleration profile.
    public func startSpeedForDegrees(degrees: UInt32, speed: Speed, maxPower: Int8, endState: MotorState, flags: [ ProfileFlag ]) {
        sendOutputCommand(request: .startSpeedForDegrees(degrees: degrees, speed: speed, maxPower: maxPower, endState: endState, flags: flags), immediate: false, handler: nil)
    }
    
    /// Start the motor with a speed  using a maximum power and moves to the absolute position. After position is reached the motor is stopped using the end state.
    ///
    /// - parameter position The absolute position.
    /// - parameter speed The speed.
    /// - parameter maxPower The max power to use.
    /// - parameter endState The end state after the time.
    /// - parameter flags The profile flags to control the use of the acceleration and deceleration profile.
    public func gotoAbsolutePosition(position: Int32, speed: Speed, maxPower: Int8, endState: MotorState, flags: [ ProfileFlag ]) {
        sendOutputCommand(request: .gotoAbsolutePosition(position: position, speed: speed, maxPower: maxPower, endState: endState, flags: flags), immediate: false, handler: nil)
    }
    
    /// Preset the encoder of the motor to Position. A 0 (zero) value equals reset.
    ///
    /// - parameter mode The mode.
    /// - parameter position The position to set.
    public func presetEncoder(mode: UInt8, position: Int32) {
        sendOutputCommand(request: .presetEncoder(mode: mode, position: position), immediate: false, handler: nil)
    }
    
}

/// A virtual port representing two linear motors that are synchronized.
public class DualLinearMotorPort: VirtualPort {
    // speed (PCT)
    public let speed = IntPortValue(mode: 1)
    // pos (DEG)
    public let position = IntPortValue(mode: 2)
    // apos (DEG)
    public let absolutePosition = IntPortValue(mode: 3)
    // load (pct)
    public let load = IntPortValue(mode: 4)

    /// Creates a new port.
    ///
    /// - parameter hub The hub.
    /// - parameter portId The port id.
    /// - parameter port1 The linear motor.
    /// - parameter port2 The second linear motor.
    public init(hub: Hub, portId: UInt8, port1: Port, port2: Port) {
        super.init(hub: hub, portId: portId, deviceId: DeviceType.linearMotor.rawValue, port1: port1, port2: port2)
        speed.port = self
        position.port = self
        absolutePosition.port = self
        load.port = self
        portValues = [ speed, position, absolutePosition, load]
    }
    
    /// Subscribes all port values in a combined subscription using the specified delta.
    ///
    /// - parameter delta The delta.
    public func subscribeAll(delta: UInt32) {
        let deltas = [UInt32](repeating: delta, count: 4)
        let datasets = [UInt8].init(repeating: 0, count: 4)
        super.subscribeValues(values: [ absolutePosition, position, speed, load ], datasets: datasets, deltas: deltas)
    }
    
    
    /// Set the output power of two motors simultaneously.
    ///
    /// - parameter mode The mode.
    /// - parameter power1 The power of the first motor.
    /// - parameter power2 The power of the second motor.
    public func startPowerDual(mode: UInt8, power1: Power, power2: Power) {
        sendOutputCommand(request: .startPowerDual(mode: mode, power1: power1, power2: power2), immediate: false, handler: nil)
    }


    ///  Start or hold the motor(s) and keeping the speed without using power-levels greater than max power.
    ///
    ///  - parameter speed1 The speed to move to or hold on the first motor.
    ///  - parameter speed2 The speed to move to or hold on the second motor.
    ///  - parameter maxPower The maximum power (0..100).
    ///  - parameter flags Whether to use the acceleration and deceleration profile.
    public func startSpeedDual(speed1: Speed, speed2: Speed, maxPower: Int8, flags: [ ProfileFlag ]) {
        sendOutputCommand(request: .startSpeedDual(speed1: speed1, speed2: speed2, maxPower: maxPower, flags: flags), immediate: false, handler: nil)
    }

    ///  Start the motor(s) for time ms. keeping a speed using a maximum power. After time stopping the output using the endState.
    ///
    /// - parameter time The time to run at the speed.
    /// - parameter speed1 The speed for the first motor.
    /// - parameter speed2 The speed for the second motor.
    /// - parameter maxPower The max power to use.
    /// - parameter endState The end state after the time.
    /// - parameter flags The profile flags to control the use of the acceleration and deceleration profile.
    public func startSpeedForTimeDual(time: Int16, speed1: Speed, speed2: Speed, maxPower: Int8, endState: MotorState, flags: [ ProfileFlag]) {
        sendOutputCommand(request: .startSpeedForTimeDual(time: time, speed1: speed1, speed2: speed2, maxPower: maxPower, endState: endState, flags: flags), immediate: false, handler: nil)
    }

    /// Starts the speed for a certain number of rotations with at most max power and then ending in the specified state.
    ///
    /// - parameter degrees The number of degrees to turn.
    /// - parameter speed1 The speed for the first motor.
    /// - parameter speed2 The speed for the second motor.
    /// - parameter maxPower The max power to use.
    /// - parameter endState The end state after the time.
    /// - parameter flags The profile flags to control the use of the acceleration and deceleration profile.
    public func startSpeedForDegreesDual(degrees: UInt32, speed1: Speed, speed2: Speed, maxPower: Int8, endState: MotorState, flags: [ ProfileFlag ]) {
        sendOutputCommand(request: .startSpeedForDegreesDual(degrees: degrees, speed1: speed1, speed2: speed2, maxPower: maxPower, endState: endState, flags: flags), immediate: false, handler: nil)
    }

    /// Start the motor with a speed  using a maximum power and moves to the absolute position. After position is reached the motor is stopped using the end state.
    ///
    /// - parameter position1 The absolute position.
    /// - parameter position2 The absolute position.
    /// - parameter speed The speed.
    /// - parameter maxPower The max power to use.
    /// - parameter endState The end state after the time.
    /// - parameter flags The profile flags to control the use of the acceleration and deceleration profile.
    public func gotoAbsolutePositionDual(position1: Int32, position2: Int32, speed: Speed, maxPower: Int8, endState: MotorState, flags: [ ProfileFlag ]) {
        sendOutputCommand(request: .gotoAbsolutePositionDual(position1: position1, position2: position2, speed: speed, maxPower: maxPower, endState: endState, flags: flags), immediate: false, handler: nil)
    }


    /// Presets only the individual encoders of the synchronized motors to the positions.
    /// The synchronized virtual encoder is not affected. A value of 0 (zero) equals RESET.
    ///
    /// - parameter position1 The position for the first encoder.
    /// - parameter position2 The position for the second encoder.
    public func presetEncoderDual(position1: Int32, position2: Int32) {
        sendOutputCommand(request: .presetEncoderDual(position1: position1, position2: position2), immediate: false, handler: nil)
    }
    
}

/// A port representing a color led.
public class RgbLightPort:  HardwarePort {
    
    /// Creates a new port.
    ///
    /// - parameter hub The hub.
    /// - parameter portId The port id assigned to the port.
    /// - parameter hardwareRevision The hardware revision.
    /// - parameter softwareRevision The software revision.
    public init(hub: Hub, portId: UInt8, hardwareRevision: Version, softwareRevision: Version) {
        super.init(hub: hub, portId: portId, deviceId: DeviceType.rgbLight.rawValue, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
    }
    
    /// Sets the color of the led using an rgb value.
    ///
    /// - parameter red The red component.
    /// - parameter green The green component.
    /// - parameter blue The blue component.
    public func setColor(red: UInt8, green: UInt8, blue: UInt8) {
        if let hub {
            hub.enqueueMessage(body: .portInputFormatSetupSingle(portId: self.portId, mode: 1, delta: 1, notify: false), handler: nil)
            sendOutputCommand(request: .setRgbColor(mode: 1, red: red, green: green, blue: blue), immediate: false, handler: nil)
        }
    }
    
    /// Activates one of the color presets.
    ///
    /// - parameter preset The preset value.
    public func setColor(preset: UInt8) {
        if let hub {
            hub.enqueueMessage(body: .portInputFormatSetupSingle(portId: self.portId, mode: 0, delta: 1, notify: false), handler: nil)
            sendOutputCommand(request: .setRgbPreset(mode: 0, preset: preset), immediate: false, handler: nil)
        }
    }
    
}

/// A port representing a tilt sensor (probably based on the accelormeter).
public class TiltPort:  HardwarePort {
    // POS (DEG)
    public let pose = IntPortValue(mode: 0)
    // IMP (CNT)
    public let impact = IntPortValue(mode: 1)
    
    /// Creates a new port.
    ///
    /// - parameter hub The hub.
    /// - parameter portId The port id assigned to the port.
    /// - parameter hardwareRevision The hardware revision.
    /// - parameter softwareRevision The software revision.
    public init(hub: Hub, portId: UInt8, hardwareRevision: Version, softwareRevision: Version) {
        super.init(hub: hub, portId: portId, deviceId: DeviceType.tiltSensor.rawValue, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
        pose.port = self
        impact.port = self
        portValues = [ pose, impact ]
    }
    
    /// (P)Resets the impact counts.
    ///
    /// - parameter preset The value to set to (0 for reset).
    public func tiltImpactPreset(preset: Int32) {
        sendOutputCommand(request: .tiltImpactPreset(preset: preset), immediate: false, handler: nil)
    }
    
    /// Set the default bottom side (orientation).
    ///
    ///  - parameter orientation The orientation to set.
    public func tiltImpactConfig(impactThreshold: Int8, bumpHoldoff: Int8) {
        sendOutputCommand(request: .tiltConfigImpact(impactThreshold: impactThreshold, bumpHoldoff: bumpHoldoff), immediate: false, handler: nil)
    }
    
    ///  Sets the Impact size for a BUMP.
    ///
    /// - parameter impactThreshold Sets the minimum Holdoff time between individual impacts (Bumps).
    /// - parameter bumpHoldoff  The HoldOff can be set between 10 ms. and 1.27 second
    public func tiltConfigOrientation(orientation: Orientation) {
        sendOutputCommand(request: .tiltConfigOrientation(orientation: orientation), immediate: false, handler: nil)
    }
    
    /// Tells the orientation set physically by the montage automat.
    ///
    /// - parameter calibration The orientation of the sensor.
    
    public func tiltFactoryConfiguration(calibration: TiltCalibration) {
        sendOutputCommand(request: .tiltFactoryCalibration(calibration: calibration), immediate: false, handler: nil)
    }
        
}

/// A port to detect some gestures (probably based on the gyro and accelerometer).
public class GesturePort:  HardwarePort {
    // GEST (-) Usually 0 but some other value, if a "gesture" has been detected.
    public let gesture = IntPortValue(mode: 0)
    
    /// Creates a new port.
    ///
    /// - parameter hub The hub.
    /// - parameter portId The port id assigned to the port.
    /// - parameter hardwareRevision The hardware revision.
    /// - parameter softwareRevision The software revision.
    public init(hub: Hub, portId: UInt8, hardwareRevision: Version, softwareRevision: Version) {
        super.init(hub: hub, portId: portId, deviceId: DeviceType.gestureSensor.rawValue, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
        gesture.port = self
        portValues = [ gesture ]
    }
  
    
}
