//
//  Network.swift - Enumerations to represent hardware
//      network messages that configure the hub's network
//      or provide updates about the network status.
//
//  Created by Marcus Handte on 26.03.23.
//

import Foundation

/// Constants used to modify or request information from the hub.
public enum NetworkOperation: UInt8 {
    /// Family Set
    case setFamily = 0x04
    /// Join Denied
    case denyJoin = 0x05
    /// Get Family
    case getFamily = 0x06
    /// Get SubFamily
    case getSubFamily = 0x08
    /// SubFamily Set
    case setSubFamily = 0x0A
    /// Get Extended Family
    case getExtendedFamily = 0x0B
    ///  Extended Family Set
    case setExtendedFamily = 0x0D
    /// Reset Long Press Timing
    case resetLongPressTiming = 0x0E
}

/// Constants to request network changes.
public enum NetworkRequest {
    /// Deny a join request.
    case denyJoin
    /// Request the current family.
    case getFamily
    /// Set the current family.
    ///
    /// - parameter family The family to set.
    case setFamily(family: UInt8)
    /// Request the current sub family.
    case getSubFamily
    /// Set the current sub family.
    ///
    /// - parameter subFamily The sub family to set.
    case setSubFamily(subFamily: UInt8)
    /// Requests the current extended family.
    case getExtendedFamily
    /// Sets the current extended family.
    ///
    /// - parameter extendedFamily The extended family to set.
    case setExtendedFamily(extendedFamily: UInt8)
    /// Resets the long -press timing.
    case resetLongPressTiming
    
    /// Encodes the request as a series of bytes.
    ///
    /// - return The bytes representing the request.
    public func encode() -> [UInt8] {
        switch self {
        case .denyJoin:
            return [ NetworkOperation.denyJoin.rawValue ]
        case .getFamily:
            return [ NetworkOperation.getFamily.rawValue ]
        case .setFamily(family: let family):
            return [ NetworkOperation.setFamily.rawValue, family ]
        case .getSubFamily:
            return [ NetworkOperation.getSubFamily.rawValue ]
        case .setSubFamily(subFamily: let subFamily):
            return [ NetworkOperation.setSubFamily.rawValue, subFamily ]
        case .getExtendedFamily:
            return [ NetworkOperation.getExtendedFamily.rawValue ]
        case .setExtendedFamily(extendedFamily: let extendedFamily):
            return [ NetworkOperation.setExtendedFamily.rawValue, extendedFamily ]
        case .resetLongPressTiming:
            return [ NetworkOperation.resetLongPressTiming.rawValue ]
        }
    }
}

/// Constants used to differentiate different network messages sent by the hub.
public enum NetworkReponse: UInt8 {
    /// Connection Request
    case connectionRequest = 0x02
    /// Family Request [New family if available]
    case familyRequest = 0x03
    /// Family
    case family = 0x07
    /// SubFamily
    case subFamily = 0x09
    /// Extended Family
    case extendedFamily = 0x0C
}

/// An enuenration to represent updates related to network messages.
public enum NetworkUpdate {
    /// A connection request with pressed button.
    ///
    /// - parameter pressed Whether the button is pressed.
    case connectionRequest(pressed: Bool)
    /// A message indicating the need for setting a family.
    case familyRequest
    /// A message transmitting the current family.
    ///
    /// - parameter family The current family.
    case family(family: UInt8)
    /// A message transmitting the current sub family.
    ///
    /// - parameter subFamily The current sub family.
    case subFamily(subFamily: UInt8)
    /// A message transmitting the current extended family.
    ///
    /// - parameter extendedFamily The current extended family.
    case extendedFamily(extendedFamily: UInt8)
    
    /// Decodes a message of a particular type from a sequence of bytes.
    ///
    /// - parameter type The type of the data to decode.
    /// - parameter data The data to decode.
    /// - returns The update contained in the data or nil, if the decoding failed.
    public static func decode(type: NetworkReponse, data: [UInt8]) -> NetworkUpdate? {
        switch type {
        case .connectionRequest:
            return .connectionRequest(pressed: data[0] == 1)
        case .familyRequest:
            return .familyRequest
        case .family:
            return .family(family: data[0])
        case .subFamily:
            return .subFamily(subFamily: data[0])
        case .extendedFamily:
            return .extendedFamily(extendedFamily: data[0])
        }
    }
}
