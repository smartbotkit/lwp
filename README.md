# SmartBotKit LWP

This repository contains a Swift library implementing the [Lego Wireless Protocol 3](https://lego.github.io/lego-ble-wireless-protocol-docs/). The Lego Wireless Protocol is the communication protocol used to interact with Lego kits that are "app controlled". Examples include 42140 or 42129, among others.

Technically, the Lego kits encompass one or more hubs that can control several motors. Different kits use different types of motors, e.g., to move a vehicle or an excavator arm. When plugged into the hub, the motors report their type to the hub, so that the hub knows the peripherals that are connected to it.

To enable the "app control", the hub is equipped with a Bluetooth LE transmitter. This allows mobile phones to interact with it by sending and receiving messages through a Bluetooth LE connection. The message types are defined in the specification of the [Lego Wireless Protocol 3](https://lego.github.io/lego-ble-wireless-protocol-docs/). 

Under the hood, the message transfer is implemented via the Generic Attribute Profile (GATT). The hub exposes a single GATT characteristic via a single service with a well-known id. The mobile phone then subscribes to changes to the data managed by the characteristic and whenever the service characteristic changes its data, the mobile phone will receive a message. To send messages, the mobile phone posts changes to the data of this characteristic.

To establish the connection between a mobile phone and the hub, the phone must be able to detect the hub. To be support discovery, the hub can send announcement frames using the Generic Access Profile (GAP). These are short messages that are broadcasted periodically accross multiple Bluetooth LE channels. To differentiate the hub from other devices that might also be using GAP for discovery, the announcement includes anothe well-known id. 

Since sending announcement frames is a waste of energy when nobody wants to "app control" the hub, the hub is equipped with a button. When pushed, the hub will send the frames for a couple of seconds. The announcements are stopped if a connection is established or the time has ran out.

## Usage

The main class is the HubManager. It interfaces with the Bluetooth LE stack of an Apple device. Using the startScanning and stopScanning functions, you can enable and disable the discovery. When a new hub is detect, you can receive a reference to it through the HubManagerDelegate. Using the Hub class you can then register for port changes using the HubDelegate. Finally, you can use the ports to interact with the different hardware components.

If you are planing on using SwiftUI, you can use a detected hub to create a MediumTechnicHub. This class provides a simpler way to access the hub's sensors. When created, it subscribes to the relevant sensors of the hub and continously provides their values via an observable object. The TransformationVehicle class extends this idea to the motor configuration used by the Lego kit 42140.

## Notes

The contents of this repository have not been developed or endorsed by the Bluetooth Alliance, Lego, or Apple. However, mentioning their names seems necessary to explain the scope and purpose of the library contained in it.

