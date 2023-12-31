//
//  Feedback.swift - Enumerations to represent feedback
//      generated by the hub. This includes acknowledgements
//      as well as error messages.
//
//  Created by Marcus Handte on 25.03.23.
//

import Foundation

/// Represents a feedback message sent by the hub.
public enum FeedbackUpdate {
    /// An acknowledgement of a specifc command.
    case acknowledge
    /// An execution error reported by the hub.
    ///
    /// - parameter code The type of error.
    case error(code: ErrorCode)
    
    /// Decodes the update from a type constant.
    ///
    /// - parameter type The type constant.
    /// - returns The feedback update.
    public static func decode(type: UInt8) -> FeedbackUpdate? {
        if type == 0x01 {
            return .acknowledge
        } else if let code = ErrorCode(rawValue: type) {
            return .error(code: code)
        }
        return nil
    }
}

/// Represents an error code contained in an error feedback of the hub.
public enum ErrorCode: UInt8 {
    /// nack
    case nack = 0x02
    /// Buffer overflow
    case overflow = 0x03
    /// Timeout
    case timeout = 0x04
    /// Command not recognized
    case invalidCommand = 0x05
    /// Invalid command usage (parameter error)
    case invalidParameters = 0x06
    /// Over current
    case overCurrent = 0x07
    /// Internal error
    case internalError = 0x08
}
