//
//  MediumTechnicHub.swift - Implements an observable wrapper class for
//      the technic medium hub that automatically registers the sensor
//      listeners and provides updates on a configurable queue.
//
//  Created by Marcus Handte on 09.04.23.
//

import Foundation
import Combine

/// An nicer programming abstraction for Lego Technic Medium Hubs.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public class MediumTechnicHub: MediumTechnicHubBase<MediumTechnicHubSensorValues> {
    
    /// Creates a new hub that delivers events on the main queue.
    ///
    /// - parameter hub The hub to interact with.
    public convenience init(hub: Hub) {
        self.init(hub: hub, queue: DispatchQueue.main)
    }

    /// Creates a new hub that delivers events on the specified queue.
    ///
    /// - parameter hub The hub to interact with.
    /// - parameter queue The dispatch queue used to deliver events.
    public init(hub: Hub, queue: DispatchQueue) {
        super.init(hub: hub, sensors: MediumTechnicHubSensorValues(), queue: queue)
    }
    
}

/// Base class for vehicles based on Lego Technic Medium Hubs that handles
/// the subscription to input ports and delivers updates on a particular queue.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public class MediumTechnicHubBase<S: MediumTechnicHubSensorValues>: NSObject, ObservableObject, HubDelegate {
    
    /// The hub.
    public weak var hub: Hub?
    /// The sensor values as observable object.
    public let sensorValues: S
    /// A reference to the first temperature port.
    private(set) public var temperaturePort1: TemperaturePort? { willSet { objectWillChange.send() }}
    /// A reference to the second temperature port.
    private(set) public var temperaturePort2: TemperaturePort? { willSet { objectWillChange.send() }}
    /// A reference to the current  port.
    private(set) public var currentPort: CurrentPort? { willSet { objectWillChange.send() }}
    /// A reference to the voltage port.
    private(set) public var voltagePort: VoltagePort? { willSet { objectWillChange.send() }}
    /// A reference to the gyroscope port.
    private(set) public var gyroPort: GyroPort? { willSet { objectWillChange.send() }}
    /// A reference to the tilt port.
    private(set) public var tiltPort: TiltPort? { willSet { objectWillChange.send() }}
    /// A reference to the gesture recognition port.
    private(set) public var gesturePort: GesturePort? { willSet { objectWillChange.send() }}
    /// A reference to the accelerometer port.
    private(set) public var accelerationPort: AccelerationPort? { willSet { objectWillChange.send() }}
    /// A reference to the led port.
    private(set) public var rgbLightPort: RgbLightPort? { willSet { objectWillChange.send() }}

    /// The cancellable that we must hold to continue to observe the sensors.
    private var sensorsCancellable: Cancellable?

    /// The dispatch queue used to deliver value updates.
    public let queue: DispatchQueue
    
    /// Creates a new hub with the specified sensors that delivers events on the
    /// specified dispatch queue.
    ///
    /// - parameter hub The hub.
    /// - parameters sensors The sensor data container.
    /// - parameters queue The dispatch queue to deliver changes.
    public init(hub: Hub, sensors: S, queue: DispatchQueue) {
        self.hub = hub
        self.queue = queue
        self.sensorValues = sensors
        super.init()
        hub.delegate = self
        sensorsCancellable = sensors.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
        
    /// Called when a port is added. This will add the port to the local variables
    /// and for sensor ports, it will trigger the subscription at the variable required
    /// to populate the sensor values. Note that we do not overwrite portRemoved
    /// since this class only handles the built-in ports which should never go away.
    ///
    /// - parameter hub The hub.
    /// - parameter port The added port.
    public func portAdded(hub: Hub, port: Port) {
        if port.portId == 50, let p = port as? RgbLightPort {
            queue.async {
                self.rgbLightPort = p
            }
        }
        if port.portId == 59, let p = port as? CurrentPort {
            queue.async {
                self.currentPort = p
            }
            p.delegate = { _ in
                p.currentLong.subscribe(delta: 5, notify: true)
            }
            p.currentLong.delegate = { [weak self] pv, vs in
                self?.queue.async {
                    self?.sensorValues.current = vs.first
                }
            }
        }
        if port.portId == 60, let p = port as? VoltagePort {
            queue.async {
                self.voltagePort = p
            }
            p.delegate = { _ in
                p.voltageLong.subscribe(delta: 5, notify: true)
            }
            p.voltageLong.delegate = { [weak self] pv, vs in
                self?.queue.async {
                    self?.sensorValues.voltage = vs.first
                }
            }
        }
        if port.portId == 61, let p = port as? TemperaturePort {
            queue.async {
                self.temperaturePort1 = p
            }
            p.delegate = { _ in
                p.temperature.subscribe(delta: 10, notify: true)
            }
            p.temperature.delegate = { [weak self] pv, vs in
                self?.queue.async {
                    self?.sensorValues.temperature1 = vs.first
                }
            }
        }
        if port.portId == 96, let p = port as? TemperaturePort {
            queue.async {
                self.temperaturePort2 = p
            }
            p.delegate = { _ in
                p.temperature.subscribe(delta: 10, notify: true)
            }
            p.temperature.delegate = { [weak self] pv, vs in
                self?.queue.async {
                    self?.sensorValues.temperature2 = vs.first
                }
            }
        }
        if port.portId == 97, let p = port as? AccelerationPort {
            queue.async {
                self.accelerationPort = p
            }
            p.delegate = { _ in
                p.gravity.subscribe(delta: 1, notify: true)
            }
            p.gravity.delegate = { [weak self] pv, vs in
                self?.queue.async {
                    self?.sensorValues.acceleration = vs
                }
            }
        }
        if port.portId == 98, let p = port as? GyroPort {
            queue.async {
                self.gyroPort = p
            }
            p.delegate = { _ in
                p.rotation.subscribe(delta: 1, notify: true)
            }
            p.rotation.delegate = { [weak self] pv, vs in
                self?.queue.async {
                    self?.sensorValues.rotation = vs
                }
            }
        }
        if port.portId == 99, let p = port as? TiltPort {
            queue.async {
                self.tiltPort = p
            }
            p.delegate = { _ in
                p.pose.subscribe(delta: 1, notify: true)
            }
            p.pose.delegate = { [weak self] pv, vs in
                self?.queue.async {
                    self?.sensorValues.pose = vs
                }
            }
        }
        if port.portId == 100, let p = port as? GesturePort {
            queue.async {
                self.gesturePort = p
            }
            p.delegate = { _ in
                p.gesture.subscribe(delta: 1, notify: true)
            }
            p.gesture.delegate = { [weak self] pv, vs in
                if let v = vs.first {
                    self?.queue.async {
                        self?.sensorValues.gesture = v
                    }
                }
            }
        }
    }
    
}

/// A class to store the sensor values of medium hub and to make them
/// easily accessible to observers such as Swift UI views.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public class MediumTechnicHubSensorValues: NSObject, ObservableObject {
    
    /// The current in milliampere.
    internal(set) public var current: Int? { willSet { objectWillChange.send() }}
    /// The voltage in millivolts.
    internal(set) public var voltage: Int? { willSet { objectWillChange.send() }}
    /// The temperature of the first sensor in centigrade.
    internal(set) public var temperature1: Float? { willSet { objectWillChange.send() }}
    /// The temperature of the second sensor in centigrade.
    internal(set) public var temperature2: Float? { willSet { objectWillChange.send() }}
    /// The angular velocity of the gyroscope.
    internal(set) public var rotation: [Int]? { willSet { objectWillChange.send() }}
    /// The values of the accelerometer.
    internal(set) public var acceleration: [Int]? { willSet { objectWillChange.send() }}
    /// The physical rotation of the device in degree provided by the tilt sensor.
    internal(set) public var pose: [Int]? { willSet { objectWillChange.send() }}
    /// The detected gesture or 0 if none.
    internal(set) public var gesture: Int = 0 { willSet { objectWillChange.send() }}
    
}

