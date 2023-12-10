//
//  TransformationVehicle.swift - An extension of the medium technic hub
//      that also fetches the motors in the configuration used for
//      the 42120 transformation vehicle kit.
//
//  Created by Marcus Handte on 07.12.23.
//
import Foundation
import Combine

/// A class to represent the transformation vehicle.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public class TransformationVehicle: MediumTechnicHubBase<TransformationVehicleSensors> {
    
    /// The first motor of the vehcile.
    private(set) public var motorPort1: LinearMotorPort? { willSet { objectWillChange.send() }}
    /// The second motor of the vehicle.
    private(set) public var motorPort2: LinearMotorPort? { willSet { objectWillChange.send() }}
    /// A combined port to control both motors simultaneously.
    private(set) public var motorsPort: VirtualPort? { willSet { objectWillChange.send() }}
    
    /// Creates a new vehicle that delivers events on the main queue.
    ///
    /// - parameter hub The hub to interact with.
    public convenience init(hub: Hub) {
        self.init(hub: hub, queue: DispatchQueue.main)
    }

    /// Creates a new vehicle that delivers events on the specified queue.
    ///
    /// - parameter hub The hub to interact with.
    /// - parameter queue The dispatch queue used to deliver events.
    public init(hub: Hub, queue: DispatchQueue) {
        super.init(hub: hub, sensors: TransformationVehicleSensors(), queue: queue)
    }
    
    /// Called when a port is added. This will setup the ports.
    ///
    /// - parameter hub The hub.
    /// - parameter port The port.
    public override func portAdded(hub: Hub, port: Port) {
        super.portAdded(hub: hub, port: port)
        if port.portId == 0, let p = port as? LinearMotorPort {
            setupMotor(port: p, values: sensorValues.motor1)
            /// memorize port
            queue.async {
                self.motorPort1 = p
            }
        }
        if port.portId == 1, let p = port as? LinearMotorPort {
            setupMotor(port: p, values: sensorValues.motor2)
            /// memorize port
            queue.async {
                self.motorPort2 = p
            }
        }
        if port.portId == 16, let p = port as? DualLinearMotorPort {
            p.delegate = { port in
                print("Setup complete.")
            }
            queue.async {
                self.motorsPort = p
            }
        }
    }
    
    /// Subscribes the port values and transfers them to the values.
    ///
    /// - parameter port The port.
    /// - parameter values The values to update.
    func setupMotor(port: LinearMotorPort, values: LinearMotorSensorValues) {
        port.speed.delegate = { [weak self]  _, value in
            self?.queue.async {
                values.speed = value.first
            }
        }
        port.position.delegate = { [weak self]  _, value in
            self?.queue.async {
                values.position = value.first
            }
        }
        port.angle.delegate = { [weak self]  _, value in
            self?.queue.async {
                values.angle = value.first
            }
        }
        port.load.delegate = { [weak self]  _, value in
            self?.queue.async {
                values.load = value.first
            }
        }
        /// subscribe after creation
        port.delegate = { [weak self] _ in
            port.subscribeAll(delta: 1)
            if let s = self, let m1 = s.motorPort1, let m2 = s.motorPort2, m1.status == .initialized, m2.status == .initialized {
                s.createVirtualPort(port1: m1, port2: m2)
            }
        }
    }
    
    /// Requests the creation of a virtual port between the two ports.
    ///
    /// - parameter port1 The first port.
    /// - parameter port2 The second port.
    func createVirtualPort(port1: Port, port2: Port) {
        // The firmware does not delete the virtual port between
        // motor1 and motor2 when the device disconnects. In addition,
        // the port will not be announced as being existing upon reconnect.
        // As a workaround, we first disconnect the usual port id - which will
        // fail if the device just booted but this will guarantee that
        // the motors are not already in a virtual port that we cannot discover.
        self.hub?.enqueueMessage(body: .virtualPortSetupRequest(request: .disconnect(virtualPortId: 16)), handler: nil)
        // Now that everything is defintively disconnected, we can begin
        // our setup and it will not fail.
        self.hub?.enqueueMessage(body: .virtualPortSetupRequest(request: .connect(portId1: port1.portId, portId2: port2.portId)), handler: nil)
         
    }
    
    /// Called when a port is removed.
    public func portRemoved(hub: Hub, port: Port) {
        super.portAdded(hub: hub, port: port)
        if port.portId == 0 {
            queue.async {
                self.motorPort1 = nil
            }
        }
        if port.portId == 1 {
            queue.async {
                self.motorPort2 = nil
            }
        }
        if port.portId == 16 {
            queue.async {
                self.motorsPort = nil
            }
        }
    }
    
}

/// Extends the sensor values of the hub with the motor values of the transformation vehicle.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public class TransformationVehicleSensors: MediumTechnicHubSensorValues {
 
    /// The sensor values of the 1st motor.
    public let motor1 = LinearMotorSensorValues()
    /// The sensor values of the 2nd motor.
    public let motor2 = LinearMotorSensorValues()
    /// The registration for value changes of the 1st motor.
    private var motor1Cancellable: Cancellable?
    /// The registration for value changes of the 2nd motor.
    private var motor2Cancellable: Cancellable?
    
    /// Creates a new set of values.
    public override init() {
        super.init()
        motor1Cancellable = motor1.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        motor2Cancellable = motor2.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

/// A class to hold the sensor values of a linear motor.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public class LinearMotorSensorValues: NSObject, ObservableObject {
    
    /// The absolute wheel position in degrees.
    internal(set) public var position: Int? { willSet { objectWillChange.send() }}
    /// The wheel angle in degrees.
    internal(set) public var angle: Int? { willSet { objectWillChange.send() }}
    /// The motor speed.
    internal(set) public var speed: Int? { willSet { objectWillChange.send() }}
    /// The motor load.
    internal(set) public var load: Int? { willSet { objectWillChange.send() }}
    
}

