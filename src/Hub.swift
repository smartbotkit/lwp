//
//  Hub.swift - Represents a hub.
//
//  Created by Marcus Handte on 22.03.23.
//

import Foundation
import CoreBluetooth

/// Represents a Bluetooth hub with a number of ports connected to it.
public class Hub: NSObject, CBPeripheralDelegate {
    
    /// The peripheral representing the hub.
    let peripheral: CBPeripheral
    /// The manager that created the peripheral.
    weak var manager: HubManager?
    /// The service that is used to interact with the hub.
    var service: CBService?
    /// The single characteristic to exchange messages with the hub.
    var characteristic: CBCharacteristic?
    /// The decoder to convert changes to the characteristic to messages.
    let decoder = ResponseDecoder()
    /// The encoder to convert requests to packets that can be sent to the characteristic.
    let encoder = RequestEncoder()
    /// The ports that we received from the device.
    public var ports: [UInt8:Port] = [:]
    /// The dispatch queue to manage the ongoing transmissions.
    var queue: TransmissionQueue!
    /// The handler for the current transmission.
    var handler: ((TransmissionError?)->Void)?
    /// An optional delegate to track changes to ports.
    public var delegate: HubDelegate?
    
    /// Initializes the hub using the manager and the peripheral.
    ///
    /// - parameter manager The bluetooth manager managing the hub.
    /// - parameter peripheral The peripheral representing the hub.
    public init(manager: HubManager, peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.manager = manager
        super.init()
        self.queue = TransmissionQueue(hub: self)
        self.peripheral.delegate = self
    }
    
    /// Called by the manager and the peripheral delegate methods to initalize the hub.
    public func initialize() {
        if let s = service {
            if let c = characteristic {
                if !c.isNotifying {
                    manager?.hubInitialized(hub: self)
                    peripheral.setNotifyValue(true, for: c)
                }
            } else {
                peripheral.discoverCharacteristics([HubId.characteristic.toUuid()], for: s)
            }
        } else {
            peripheral.discoverServices([HubId.service.toUuid()])
        }
    }
    
    /// Disconnects from the peripheral, if we are still connected.
    public func disconnect() {
        if let c = characteristic {
            if c.isNotifying {
                peripheral.setNotifyValue(false, for: c)
            }
        }
        if let m = manager, peripheral.state == .connected || peripheral.state == .connecting {
            m.manager.cancelPeripheralConnection(peripheral)
        }
    }
    
    /// Called by the peripheral when the characteristics have been discovered for a particular service.
    /// This function will memorize the characteristic which we can use to communicate with the hub
    /// or signal an initalization error.
    ///
    /// - parameter peripheral The peripheral.
    /// - parameter service The service.
    /// - parameter error An error, if one ocurred.
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard self.characteristic == nil else {
            return
        }
        if let error {
            self.manager?.hubError(hub: self, error: error)
        } else {
            self.characteristic = service.characteristics?.first(where: { $0.uuid == HubId.characteristic.toUuid()})
            initialize()
        }
    }
    
    /// Called by the peripheral when the services have been discovered. This function
    /// will memorize the service used to communicate with the hub or signal an initalization
    /// error.
    ///
    /// - parameter peripheral The peripheral.
    /// - parameter error An error, if one occured.
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard self.service == nil else {
            return
        }
        if let error {
            self.manager?.hubError(hub: self, error: error)
        } else {
            self.service = peripheral.services?.first(where: { $0.uuid == HubId.service.toUuid() })
            initialize()
        }
    }
    
    /// Called by the peripheral when the notification state for a characteristic has been changed.
    ///
    /// - parameter peripheral The peripheral.
    /// - parameter characteristic The characteristic.
    /// - parameter error An error, if one occured.
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == self.characteristic?.uuid else {
            return
        }
        if let error {
            manager?.hubError(hub: self, error: error)
        } else {
            self.characteristic = characteristic
        }
    }
    
    /// Called when the characteristic value on the peripheral changes. This will try to decode
    /// the messages represented by the value.
    ///
    /// - parameter peripheral The peripheral that sent some data.
    /// - parameter characteristic The characteristic that sent the data.
    /// - parameter error An error that might have occured.
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            let messages = decoder.decode(data: data)
            for message in messages {
                #if HEAVY_DEBUG
                print("Incoming: \(message)")
                #endif
                switch message.body {
                case .hubAttachedIo(let portId, let update):
                    handleAttachedIo(portId: portId, update: update)
                case .portInformation(portId: let portId, update: let update):
                    handlePortInformation(portId: portId, update: update)
                case .portModeInformation(portId: let portId, mode: let mode, update: let update):
                    handlePortModeInformation(portId: portId, mode: mode, update: update)
                case .portValueSingle(portId: let portId, data: let data):
                    if let port = ports[portId] {
                        port.setValue(data: data)
                    }
                case .portValueCombined(portId: let portId, modes: let modes, data: let data):
                    if let port = ports[portId] {
                        port.setValues(modes: modes, data: data)
                    }
                case .portInputFormatSingle, .portInputFormatCombined:
                    break
                default:
                    print("Unhandled message \(message)")
                }
                queue.receiveMessage(body: message.body)
            }
        }
    }

    /// Handles a port information or port mode update. This will update
    /// the sensor value or the
    ///
    /// - parameter portId The port id.
    /// - parameter mode The mode.
    /// - parameter update The port mode update.
    private func handlePortModeInformation(portId: UInt8, mode: UInt8, update: PortModeUpdate) {
        if let port = ports[portId], var info = port.modeInformation[mode] {
            switch update {
            case .name(name: let name):
                info.name = name
            case .raw(range: let range):
                info.rawRange = range
            case .pct(range: let range):
                info.percentRange = range
            case .si(range: let range):
                info.siRange = range
            case .symbol(name: let name):
                info.symbol = name
            case .mapping(mapping: let mapping):
                info.mapping = mapping
            case .motorBias(bias: let bias):
                info.motorBias = bias
            case .capabilityBits(capabilities: let capabilities):
                info.capabilites = capabilities
            case .valueFormat(format: let format):
                info.format = format
            }
            port.modeInformation[mode] = info
            if let delegate {
                delegate.portUpdated(hub: self, port: port)
            }
        }
        
    }
    
    /// Handles port information messages by updating the corresponding ports.
    ///
    /// - parameter portId The port id.
    /// - parameter update The port information.
    private func handlePortInformation(portId: UInt8, update: PortInformationUpdate) {
        if let port = ports[portId] {
            switch update {
            case .modeInfo(input: let input, output: let output, combinable: let combinable, synchronizable: let synchronizable, modeCount: _, inputModes: let inputModes, outputModes: let outputModes):
                var info = PortInformation(input: input, output: output, combinable: combinable, synchronizable: synchronizable, inputModes: inputModes, outputModes: outputModes)
                if !combinable {
                    info.modeCombinations = []
                }
                port.information = info
            case .modeCombinations(modeCombinations: let modeCombinations):
                if port.information != nil {
                    port.information!.modeCombinations = modeCombinations
                }
            }
            if let delegate {
                delegate.portUpdated(hub: self, port: port)
            }
        }
    }
    
    /// Handles messages that signal changes to the ports.
    ///
    /// - parameter portid The port id.
    /// - parameter update The update.
    private func handleAttachedIo(portId: UInt8, update: IoUpdate) {
        switch update {
        case .detached:
            #if DEBUG
            print("Port detached \(portId)")
            #endif
            if let port = ports.removeValue(forKey: portId) {
                if let delegate {
                    delegate.portRemoved(hub: self, port: port)
                }
            }
        case .attachedVirtual(let deviceId, let deviceType, let portId1, let portId2):
            #if DEBUG
            print("Virtual port attached \(portId) [\(deviceId),\(String(describing: deviceType)),\(portId1),\(portId2)]")
            #endif
            if let port1 = ports[portId1], let port2 = ports[portId2] {
                if let deviceType, deviceType == .linearMotor {
                    ports[portId] = DualLinearMotorPort(hub: self, portId: portId, port1: port1, port2: port2)
                } else {
                    ports[portId] = VirtualPort(hub: self, portId: portId, deviceId: deviceId, port1: port1, port2: port2)
                }
                if let port = ports[portId], let delegate {
                    delegate.portAdded(hub: self, port: port)
                }
                if let port = ports[portId] {
                    port.initialize()
                }
            }
        case .attached(let deviceId, let deviceType, let hardwareRevision, let softwareRevision):
            #if DEBUG
            print("Port attached \(portId) [\(deviceId),\(String(describing: deviceType)),\(hardwareRevision),\(softwareRevision)]")
            #endif
            if let deviceType {
                switch deviceType {
                case .voltageSensor:
                    ports[portId] = VoltagePort(hub: self, portId: portId, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
                case .currentSensor:
                    ports[portId] = CurrentPort(hub: self, portId: portId, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
                case .temperatureSensor:
                    ports[portId] = TemperaturePort(hub: self, portId: portId, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
                case .gyroSensor:
                    ports[portId] = GyroPort(hub: self, portId: portId, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
                case .accelerationSensor:
                    ports[portId] = AccelerationPort(hub: self, portId: portId, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
                case .linearMotor:
                    ports[portId] = LinearMotorPort(hub: self, portId: portId, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
                case .rgbLight:
                    ports[portId] = RgbLightPort(hub: self, portId: portId, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
                case .tiltSensor:
                    ports[portId] = TiltPort(hub: self, portId: portId, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
                case .gestureSensor:
                    ports[portId] = GesturePort(hub: self, portId: portId, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
                }
            } else {
                ports[portId] = HardwarePort(hub: self, portId: portId, deviceId: deviceId, hardwareRevision: hardwareRevision, softwareRevision: softwareRevision)
            }
            if let port = ports[portId], let delegate {
                delegate.portAdded(hub: self, port: port)
            }
            if let port = ports[portId] {
                port.initialize()
            }
        }
    }
    
    /// Adds a message to the transmission queue and calls the optional handler
    /// upon completion.
    ///
    /// - parameter body The messages to send.
    /// - parameter handler An optional handler to receive the result (if any) and errors.
    public func enqueueMessage(body: RequestBody, handler: ((ResponseBody?, TransmissionError?)->Void)?) {
        queue.sendMessage(body: body, handler: handler)
    }
  
    /// Sends the message directly. Must be called from the queue.
    ///
    /// - parameter body The message to send.
    /// - parameter handler A handler to receive transmission errors.
    internal func sendMessage(body: RequestBody, handler: @escaping (TransmissionError?)->Void) {
        manager?.queue.async {
            if let c = self.characteristic {
                self.handler = handler
                let request = self.encoder.encode(hub: 0x00, body: body)
                #if HEAVY_DEBUG
                print("Outgoing: \(request)")
                #endif
                let data = Data(request.data)
                self.peripheral.writeValue(data, for: c, type: .withResponse)
            } else {
                handler(.serviceUnavailable)
            }
        }
    }
    
    /// Called when the hub has finished changing the characteristic. This will
    /// forward the error and notify the handler.
    ///
    /// - parameter peripheral The peripheral to which we sent some data.
    /// - parameter characteristic The characteristic used for sending.
    /// - parameter error An error, if one occured.
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let h = handler {
            if let e = error {
                h(.transmissionFailed(error: e))
            } else {
                h(nil)
            }
            handler = nil
        }
    }
}

/// Represents a transmission error that is raised when a command
/// is sent to the hub.
public enum TransmissionError: Error {
    /// The hub is no longer available.
    case hubUnavailable
    /// The service is not available.
    case serviceUnavailable
    /// The transmission of a command failed.
    case transmissionFailed(error: Error?)
}

/// A queue that is used to send commands sequentially to the hub.
class TransmissionQueue {
    /// The hub used to send the messages.
    private weak var hub: Hub?
    /// The dispatch queue to transmit messages sequentially.
    private let queue: DispatchQueue
    /// The group to wait for a response.
    private let group = DispatchGroup()
    /// The lock used to synchronize the reception and transmission.
    private let lock = NSLock()
    
    /// The request that is currently running.
    private var request: RequestBody?
    /// The transmission error caused by the request.
    private var error: TransmissionError?
    /// The response for the request.
    private var response: ResponseBody?
    
    /// Creates a new queue  for the hub.
    ///
    /// - parameter hub The bluetooth hub.
    public init(hub: Hub) {
        self.hub = hub
        self.queue = DispatchQueue(label: "com.smartbotkit.lwp.\(hub.peripheral.identifier)")
    }
    
    /// Sends a message and returns the response or error through the (optional) handler.
    ///
    /// - parameter body The message to send.
    /// - parameter handler The handler to receive the response or error.
    public func sendMessage(body: RequestBody, handler: ((ResponseBody?, TransmissionError?)->Void)?) {
        if let hub {
            queue.async {
                self.lock.lock()
                self.request = body
                self.group.enter()
                self.lock.unlock()
                hub.sendMessage(body: body) {
                    error in
                    if let error {
                        self.error = error
                        self.group.leave()
                    } else if !body.hasResponse() {
                        self.group.leave()
                    }
                }
                self.group.wait()
                self.lock.lock()
                let e = self.error
                let r = self.response
                self.error = nil
                self.response = nil
                self.request = nil
                self.lock.unlock()
                if let handler {
                    handler(r, e)
                }
            }
        } else {
            if let handler {
                queue.async {
                    handler(nil, .hubUnavailable)
                }
            }
        }
    }
    
    /// Called by the hub when a message is received and unblocks the
    /// current caller if the message is the expected response for the
    /// curently running request.
    ///
    /// - parameter body The response.
    public func receiveMessage(body: ResponseBody) {
        self.lock.lock()
        if let request, request.isResponse(response: body) {
            self.response = body
            self.group.leave()
        }
        self.lock.unlock()
    }
}

/// A protocol to detect changes in the ports of a hub.
public protocol HubDelegate {
    /// Called when a new port has been added.
    ///
    /// - parameter hub The hub originating the request.
    /// - parameter port The port that has been added.
    func portAdded(hub: Hub, port: Port)
    /// Called when an existing port has been removed.
    ///
    /// - parameter hub The hub originating the request.
    /// - parameter port The port that has been removed..
    func portRemoved(hub: Hub, port: Port)
    /// Called when an existing port has been updated.
    ///
    /// - parameter hub The hub originating the request.
    /// - parameter port The port that has been updated.
    func portUpdated(hub: Hub, port: Port)
}

/// Adds default implementations for the functions.
public extension HubDelegate {
    
    /// Prints the port in debug mode.
    func portAdded(hub: Hub, port: Port) {
        #if DEBUG
        print("Port added: \(hub.peripheral.identifier) \(port.portId)")
        #endif
    }

    /// Prints the port in debug mode.
    func portRemoved(hub: Hub, port: Port) {
        #if DEBUG
        print("Port removed: \(hub.peripheral.identifier) \(port.portId)")
        #endif
    }

    /// Does nothing
    func portUpdated(hub: Hub, port: Port) {
        #if HEAVY_DEBUG
        print("Port updated: \(hub.peripheral.identifier) \(port.portId)")
        #endif
    }
    
}
