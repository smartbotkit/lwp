//
//  Actions.swift - Enumerations related to hub actions.
//
//  Created by Marcus Handte on 25.03.23.
//

import Foundation

/// The constants for encoding different actions sent to the hub.
public enum ActionRequest: UInt8, CaseIterable {
    /// Switch Off Hub.
    case switchOff = 0x01
    /// Disconnect.
    case disconnect = 0x02
    /// VCC Port Control On.
    case enableVccPortControl = 0x03
    /// VCC Port Control Off.
    case disableVccPortControl = 0x04
    /// Activate BUSY Indication (shown by RGB. Actual RGB settings preserved).
    case enableBusyIndication = 0x05
    /// Reset BUSY Indication (RGB shows the previously preserve RGB settings).
    case disableBusyIndication = 0x06
    /// Shutdown the Hub without any up-stream information send. Used for fast power down in production.
    case shutdown = 0x2F
}

/// The constants for signal different actions received from the hub.
public enum ActionUpdate: UInt8, CaseIterable {
    /// Hub wlll switch off.
    case switchOff = 0x30
    /// Hub will disconnect.
    case disconnect = 0x31
    /// Hub will go into boot mode.
    case bootMode = 0x32
}