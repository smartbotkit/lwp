//
//  HubManager.swift - The class to manage the communication
//      with Bluetooth hubs.
//
//  Created by Marcus Handte on 15.03.23.
//

import Foundation
import CoreBluetooth

/// A manager for the communication with a Bluetooth hub.
public class HubManager: NSObject, CBCentralManagerDelegate {
    
    /// The manager to interact with CoreBluetooth.
    let manager: CBCentralManager
    /// The dispatch queue that will receive messages.
    let queue: DispatchQueue
    /// The Bluetooth hubs that we discovered.
    var hubs: [UUID:Hub] = [:]
    /// A flag to indicate whether the hub should be scanning.
    var scanning = false
    /// A delegate to track hubs.
    public var delegate: (any HubManagerDelegate)?

    /// Creates a new manager with a new dispatch queue.
    public override convenience init() {
        self.init(queue: DispatchQueue(label: "com.smartbotkit.lwp", qos: .default))
    }
    
    /// Creates a new manager with the specified dispatch queue.
    ///
    /// - parameter queue The dispatch queue.
    public init(queue: DispatchQueue) {
        self.queue = queue
        manager = CBCentralManager(delegate: nil, queue: queue)
        super.init()
        manager.delegate = self
    }
    
    /// Called when the CoreBluetooth state is updated. This will (re-) start the scan, if the
    /// manager is still supposed to be scanning.
    ///
    /// - parameter central The CoreBluetooth manager.
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if case .poweredOn = central.state {
            if (scanning && !manager.isScanning) {
                manager.scanForPeripherals(withServices: [ HubId.service.toUuid() ])
            }
        }
    }
    
    /// Called by a hub, when the initialization has completed successfully.
    ///
    /// - parameter hub The hub that has been initialized.
    public func hubInitialized(hub: Hub) {
        hubs[hub.peripheral.identifier] = hub
        if let delegate {
            delegate.hubInitialized(manager: self, hub: hub)
        }
    }
    
    /// Called by a hub, when the hub initialization failed.
    ///
    /// - parameter hub The hub that has failed.
    /// - parameter error The error experienced by the hub.
    public func hubError(hub: Hub, error: Error) {
        if hubs[hub.peripheral.identifier] != nil {
            if let delegate {
                delegate.hubError(manager: self, hub: hub, error: error)
            }
            hub.disconnect()
        }
    }
    
    /// Starts scanning for a Bluetooth hub.
    public func startScanning() {
        if !scanning {
            scanning = true
            if manager.state == .poweredOn {
                manager.scanForPeripherals(withServices: [ HubId.service.toUuid() ])
            }
        }
    }
    
    /// Stops scanning for a Bluetooth hub.
    public func stopScanning() {
        if scanning {
            scanning = false
            if manager.isScanning {
                manager.stopScan()
            }
        }
    }
    
    /// Called by Core Bluetooth when a device is discovered. This function will create a new hub for each
    /// new device that has been discovered and then it will try to establish a connection.
    ///
    /// - parameter central The Core Bluetooth manager.
    /// - parameter peripheral The device that has been detected.
    /// - parameter advertisementData The data contained in the BLE advertisement.
    /// - parameter rssi The signal strength.
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let info = DeviceAdvertisement(advertisementData: advertisementData), hubs[peripheral.identifier] == nil {
            #if DEBUG
            print("Device discovered: \(peripheral.identifier)")
            #endif
            #if HEAVY_DEBUG
            print("Device information: \(String(describing: info))")
            #endif
            hubs[peripheral.identifier] = Hub(manager: self, peripheral: peripheral)
            manager.connect(peripheral)
        }
    }
    
    /// Called by Core Bluetooth when a device connection has been established. This function will  trigger
    /// the initialization of  the hub.
    ///
    /// - parameter central The Core Bluetooth manager.
    /// - parameter peripheral The device that has connected.
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let hub = hubs[peripheral.identifier] {
            #if DEBUG
            print("Device connection established: \(peripheral.identifier)")
            #endif
            hub.initialize()
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let h = hubs.removeValue(forKey: peripheral.identifier){
            #if DEBUG
            print("Device connection closed: \(peripheral.identifier)")
            #endif
            if let delegate {
                delegate.hubDisconnected(manager: self, hub: h)
            }
        }
    }
    
    /// Called by Core Bluetooth when a device connection attempt failed. The function will remove the hub.
    ///
    /// - parameter central The Core Bluetooth manager.
    /// - parameter peripheral The device that failed.
    /// - parameter error The failure.
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let hub = hubs[peripheral.identifier] {
            #if DEBUG
            print("Device connection failed: \(peripheral.identifier)")
            #endif
            hubs.removeValue(forKey: hub.peripheral.identifier)
        }
    }
    
}

/// A protocol to detect changes in the state of the HubManager.
public protocol HubManagerDelegate {
    /// Called when a hub is initialized. Note that this method will be called
    /// from the DispatchQueue of the manager.
    ///
    /// - parameter manager The HubManager.
    /// - parameter hub The hub that has been initialized.
    func hubInitialized(manager: HubManager, hub: Hub)
    /// Called when a hub failed. Note that this method will be called
    /// from the DispatchQueue of the HubManager.
    ///
    /// - parameter manager The HubManager.
    /// - parameter hub The hub that has failed.
    /// - parameter error The error detailing the issue.
    func hubError(manager: HubManager, hub: Hub, error: Error)
    /// Called when a hub is disconnected. Note that this will be
    /// called from the DispatchQueue of the HubManager.
    ///
    /// - parameter manager The HubManager.
    /// - parameter hub The hub that has failed.
    func hubDisconnected(manager: HubManager, hub: Hub)
}


/// Default implementations for the HubManagerDelegate that print the event in debug mode.
public extension HubManagerDelegate {
    
    func hubInitialized(manager: HubManager, hub: Hub) {
        #if DEBUG
        print("Hub initialized: \(hub.peripheral.identifier)")
        #endif
    }
    
    func hubError(manager: HubManager, hub: Hub, error: Error) {
        #if DEBUG
        print("Hub error: \(hub.peripheral.identifier) \(error)")
        #endif
    }
    
    func hubDisconnected(manager: HubManager, hub: Hub) {
        #if DEBUG
        print("Hub disconnected: \(hub.peripheral.identifier)")
        #endif
    }
}

