//
//  Protocol.swift - The basic request and response
//      types of the wireless protocol.
//
//  Created by Marcus Handte on 19.03.23.
//

import Foundation
import CoreBluetooth

/// The basic structure for a message sent from the hub.
public struct Response {
    /// The hub id that identifies the source hub.
    public let hub: UInt8
    /// The message data as a sequence of bytes (intended for debugging).
    public let data: [UInt8]
    /// The decoded response type.
    public let type: ResponseType
    /// The decoded response body.
    public let body: ResponseBody
}

/// An enumeration with the different response types and their associated byte representation.
public enum ResponseType: UInt8, CaseIterable {
    /// A message containing a hub property.
    case hubProperties = 0x01
    /// A message containing an action update.
    case hubActions = 0x02
    /// A message related to a hub alert.
    case hubAlerts = 0x03
    /// A message related to the port configuration of the hub.
    case hubAttachedIo = 0x04
    /// A message with feedback.
    case hubFeedback = 0x05
    /// A message related to the networking of hubs.
    case hardwareNetworkCommands = 0x08
    /// A message with the firmware lock status.
    case firmwareUpdateLockStatus = 0x13
    /// A message with information about a port.
    case portInformation = 0x43
    /// A message with information about a mode of a port.
    case portModeInformation = 0x44
    /// A message with a value of a single port mode.
    case portValueSingle = 0x45
    /// A message with a set of values for multiple port modes.
    case portValueCombined = 0x46
    /// A message with the input format of a port mode.
    case portInputFormatSingle = 0x47
    /// A message with a input format for multiple port modes.
    case portInputFormatCombined = 0x48
    /// A message with feedback of an output command.
    case portOutputCommand = 0x81
}

/// The different message formats for messages sent by the hub.
public enum ResponseBody {
    /// A message with a property value.
    ///
    /// - parameter type The (raw) property that is updated.
    /// - parameter value The (raw) value of the property.
    /// - parameter update The decoded property update.
    case hubPropertyUpdate(type: PropertyType, value: [UInt8], update: PropertyUpdate)
    /// A message with a hub alert,
    ///
    /// - parameter type The alert type.
    /// - parameter value A boolean indicating whether the altert type is raised.
    case hubAlertUpdate(type: AlertType, value: Bool)
    /// A message with an action indication.
    ///
    ///  - parameter update The action udpate.
    case hubActionUpdate(update: ActionUpdate)
    /// A message signaling port changes.
    ///
    /// - parameter portId The id of the port that changed.
    /// - parameter update The update describing the change.
    case hubAttachedIo(portId: UInt8, update: IoUpdate)
    /// A message with feedback.
    ///
    /// - parameter command The command on which we received feedback.
    /// - parameter update The update describing the feedback.
    case hubFeedback(command: UInt8, update: FeedbackUpdate)
    /// A message signalling changes to the network state.
    ///
    /// - parameter update The update describing the change.
    case hardwareNetworkUpdate(update: NetworkUpdate)
    /// A message signaling the lock status of the firmware.
    ///
    /// - parameter locked True if the firmware is locked.
    case firmwareUpdateLockStatus(locked: Bool)
    /// A message with port information.
    ///
    /// - parameter portId The port.
    /// - parameter update The port information.
    case portInformation(portId: UInt8, update: PortInformationUpdate)
    /// A message with information about a port mode.
    ///
    /// - parameter portId The port.
    /// - parameter mode The mode.
    /// - parameter udpate The information about the port mode.
    case portModeInformation(portId: UInt8, mode: UInt8, update: PortModeUpdate)
    /// A message with a single value for a particular port mode.
    ///
    /// - parameter portId The port.
    /// - parameter data The data of the port.
    case portValueSingle(portId: UInt8, data: [UInt8])
    /// A message with a value for a set of port modes.
    ///
    /// - parameter portId The port.
    /// - parameter modes The modes receiving the update.
    /// - parameter data The  port data.
    case portValueCombined(portId: UInt8, modes: [UInt8], data: [UInt8])
    /// A message that describes the configuration of a single port mode.
    ///
    /// - parameter portId The port.
    /// - parameter mode The mode.
    /// - parameter delta The delta inverval which is used for message suppression.
    /// - parameter notify A flag describing whether changes are reported to the hub.
    case portInputFormatSingle(portId: UInt8, mode: UInt8, delta: UInt32, notify: Bool)
    /// A message that describes the configuration of a combined port mode.
    ///
    /// - parameter portId The port.
    /// - parameter control The control..
    /// - parameter combination The mode combination.
    case portInputFormatCombined(portId: UInt8, control: UInt8, combination: [UInt8])
    /// A message providing feedback on a port output command.
    ///
    /// - parameter states The port states.
    case portOutputCommand(states: [PortOutputState])
    /// A message that cannot be decoded. This should not
    /// be generated.
    case unknown
}

/// The basic structure for a message sent to the hub.
public struct Request {
    /// The hub id that identifies the target hub.
    public let hub: UInt8
    /// The message data as a sequence of bytes (intended for debugging).
    public let data: [UInt8]
    // The request type.
    public let type: RequestType
    // The request body.
    public let body: RequestBody
}

/// The possible message types of a request.
public enum RequestType: UInt8 {
    /// A request to set, get, subscribe, or reset hub properties.
    case hubProperties = 0x01
    /// A request to execute a hub action.
    case hubActions = 0x02
    /// A request  to change hub alerts.
    case hubAlerts = 0x03
    /// A rquest to change the hardware network.
    case hardwareNetworkCommands = 0x08
    /// A request to reboot the device for firmware updates.
    case firmwareUpdateGoIntoBootMode = 0x10
    /// A request to lock the memory.
    case firmwareUpdateLockMemory = 0x11
    /// A request to fetch the lock status of the memory.
    case firmwareUpdateLockStatus = 0x12
    /// A request to get information about a port.
    case portInformation = 0x21
    /// A request to get information about a port mode.
    case portModeInformation = 0x22
    /// A request to configure a single port input mode.
    case portInputFormatSetupSingle = 0x41
    /// A request to combine multiple input modes.
    case portInputFormatSetupCombined = 0x42
    /// A request to setup a virtual port.
    case virtualPortSetup = 0x61
    /// A request to generate a port output.
    case portOutputCommand = 0x81
}

/// An enumeration to describe the request to the hub.
public enum RequestBody {
    /// A request to get, set, subscribe or reset properties.
    ///
    /// - parameter request The type of request.
    case hubPropertyRequest(request: PropertyRequest)
    /// A request to execute a hub action.
    ///
    /// - parameter request The request details.
    case hubActionRequest(request: ActionRequest)
    /// A request  to change hub alerts.
    ///
    /// - parameter type The alert type.
    /// - parameter operation The operation.
    case hubAlertRequest(type: AlertType, operation: AlertOperation)
    
    case hardwareNetworkRequest(request: NetworkRequest)
    case firmwareUpdateGoIntoBootMode
    case firmwareUpdateLockMemory
    case firmwareUpdateLockStatus
    case portInformation(portId: UInt8, request: PortInformationRequest)
    case portModeInformation(portId: UInt8, mode: UInt8, request: PortModeType)
    case portInputFormatSetupSingle(portId: UInt8, mode: UInt8, delta: UInt32, notify: Bool)
    case portInputFormatSetupCombined(portId: UInt8, request: PortInputSetupRequest)
    case virtualPortSetupRequest(request: VirtualPortSetupRequest)
    case portOutputCommand(portId: UInt8, flags: [PortOutputFlag], request: PortOutputRequest)
    
    /// Determines whether the request should wait for a response.
    ///
    /// - returns True if the request shall wait for a response.
    public func hasResponse() -> Bool {
        switch self {
        case .portOutputCommand(portId: _, flags: let flags, request: _):
            return flags.contains(.feedback)
        case .hubPropertyRequest(request: let request):
            switch request {
            case .requestUpdate(type: _):
                return true
            default:
                return false
            }
        case .hardwareNetworkRequest(request: let request):
            switch request {
            case .getFamily, .getSubFamily, .getExtendedFamily:
                return true
            default:
                return false
            }
        case .hubAlertRequest(type: _, operation: let operation):
            switch operation {
            case .enableUpdates, .requestUpdate:
                return true
            default:
                return false
            }
        case .portInputFormatSetupCombined(portId: _, request: let request):
            switch request {
            case .unlockDisabled, .unlockEnabled:
                return true
            default:
                return false
            }
        case .hubActionRequest(request: _):
            return false
        case .firmwareUpdateLockMemory:
            return false
        default:
            return true
        }
    }
    
    /// Determines whether the response body is the response to
    /// the request.
    ///
    /// - parameter response The response.
    /// - returns True if the response matches the request.
    public func isResponse(response: ResponseBody) -> Bool {
        switch self {
        case .hubPropertyRequest(request: let request):
            switch request {
            case .requestUpdate(type: let type):
                if case .hubPropertyUpdate(let t, _, _) = response {
                    return type == t
                }
            default:
                return false
            }
            return false
        case .hubAlertRequest(type: let type, operation: let operation):
            switch operation {
            case .enableUpdates, .requestUpdate:
                if case .hubAlertUpdate(let t, _) = response {
                    return type == t
                }
            default:
                return false
            }
        case .hardwareNetworkRequest(request: let request):
            if case .hardwareNetworkUpdate(let update) = response {
                switch request {
                case .getFamily:
                    if case .family(_) = update {
                        return true
                    }
                case .getSubFamily:
                    if case .subFamily(_) = update {
                        return true
                    }
                case .getExtendedFamily:
                    if case .extendedFamily(_) = update {
                        return true
                    }
                default:
                    return false
                }
            }
        case .firmwareUpdateGoIntoBootMode:
            if case .hubActionUpdate(let update) = response {
                return update == .bootMode
            }
            return false
        case .firmwareUpdateLockStatus:
            if case .firmwareUpdateLockStatus(_) = response {
                return true
            }
            return false
        case .portInformation(portId: let portId, request: let request):
            switch request {
            case .modeInfo, .modeCombinations:
                if case .portInformation(let pid, _) = response {
                    return portId == pid
                }
            case .portValue:
                if case .portValueSingle(let pid, _) = response {
                    return portId == pid
                } else if case .portValueCombined(let pid, _, _) = response {
                    return portId == pid
                }
            }
        case .portModeInformation(portId: let portId, mode: let mode, request: _):
            if case .portModeInformation(let pid, let m, _) = response {
                return portId == pid && mode == m
            } else if case .hubFeedback(let command, _) = response {
                return command == RequestType.portModeInformation.rawValue
            }
        case .portInputFormatSetupSingle(portId: let portId, mode: let mode, delta: _, notify: _):
            if case .portInputFormatSingle(let pid, let m, _, _) = response {
                return portId == pid && mode == m
            }
        case .virtualPortSetupRequest(request: let request):
            if case .hubFeedback(let command, _) = response {
                return command == RequestType.virtualPortSetup.rawValue
            }
            switch request {
            case .connect(portId1: let p1, portId2: let p2):
                if case .hubAttachedIo(_, let update) = response {
                    if case .attachedVirtual(_, _, let portId1, let portId2) = update {
                        return p1 == portId1 && p2 == portId2
                    }
                }
                
            case .disconnect(virtualPortId: let pt):
                if case .hubAttachedIo(let portId, let update) = response {
                    if case .detached = update {
                        return pt == portId
                    }
                }
            }
            
            return false
        case .portOutputCommand(portId: let portId, flags: let flags, request: _):
            if flags.contains(.feedback) {
                if case .portOutputCommand(let states) = response {
                    for state in states {
                        if state.portId == portId {
                            return true
                        }
                    }
                }
            }
            return false
        case .portInputFormatSetupCombined(portId: let portId, request: _):
            if case .portInputFormatCombined(let pid, _, _) = response {
                return pid == portId
            }
        default:
            return false
        }
        return false
    }
}

/// Represents a version.
public struct Version: CustomStringConvertible {

    /// A string representation of the version.
    public var description: String {
        return "\(getMajor()).\(getMinor()).\(getPatch()) (\(getBuild()))"
    }
    
    /// The version code.
    let code: [UInt8]
    
    /// Creates a version from a data at an offset.
    ///
    /// - parameter data The data to read.
    /// - parameter offset The offest to start from.
    init(data: [UInt8], offset: Int) {
        var c = [UInt8](repeating: 0, count: 4)
        for i in 0..<4 {
            c[i] = data[offset + i]
        }
        code = c
    }
    
    /// Returns the major version.
    ///
    /// - returns The major version.
    public func getMajor() -> Int {
        return Int(code[3] >> 4) & 0x07
    }
    
    /// Returns the minor version.
    ///
    /// - returns The minor version.
    public func getMinor() -> Int {
        return Int(code[3]) & 0x0F
    }
    
    /// Returns the patch version.
    ///
    /// - returns The patch version.
    public func getPatch() -> Int {
        return Int(code[2])
    }
    
    /// Returns the build number.
    ///
    /// - returns The build number.
    public func getBuild() -> Int {
        return (Int(code[1]) << 8) | Int(code[0])
    }
}

/// The class that encodes the request.
public class RequestEncoder {
    
    /// Encodes the request body into a request that can be transmitted.
    ///
    /// - parameter hub The hub.
    /// - parameter body The request body.
    /// - returns The encoded request.
    public func encode(hub: UInt8, body: RequestBody) -> Request {
        switch body {
        case .hubAlertRequest(type: let alertType, operation: let operation):
            var data = [UInt8](repeating: 0, count: 5)
            data[0] = 5
            data[1] = hub
            data[2] = RequestType.hubAlerts.rawValue
            data[3] = alertType.rawValue
            data[4] = operation.rawValue
            return Request(hub: hub, data: data, type: .hubAlerts, body: body)
        case .hubActionRequest(request: let request):
            var data = [UInt8](repeating: 0, count: 4)
            data[0] = 4
            data[1] = hub
            data[2] = RequestType.hubActions.rawValue
            data[3] = request.rawValue
            return Request(hub: hub, data: data, type: .hubActions, body: body)
        case .hubPropertyRequest(request: let request):
            let requestData = request.encode()
            var data = [UInt8](repeating: 0, count: requestData.count + 3)
            data[0] = UInt8(requestData.count + 3)
            data[1] = hub
            data[2] = RequestType.hubProperties.rawValue
            for i in 0 ..< requestData.count {
                data[i + 3] = requestData[i]
            }
            return Request(hub: hub, data: data, type: .hubProperties, body: body)
        case .hardwareNetworkRequest(request: let request):
            let requestData = request.encode()
            var data = [UInt8](repeating: 0, count: requestData.count + 3)
            data[0] = UInt8(requestData.count + 3)
            data[1] = hub
            data[2] = RequestType.hardwareNetworkCommands.rawValue
            for i in 0 ..< requestData.count {
                data[i + 3] = requestData[i]
            }
            return Request(hub: hub, data: data, type: .hardwareNetworkCommands, body: body)
        case .portInformation(let portId, let requestType):
            var data = [UInt8](repeating: 0, count: 5)
            data[0] = 5
            data[1] = hub
            data[2] = RequestType.portInformation.rawValue
            data[3] = portId
            data[4] = requestType.rawValue
            return Request(hub: hub, data: data, type: .portInformation, body: body)
        case .portModeInformation(let portId, let mode, let requestType):
            var data = [UInt8](repeating: 0, count: 6)
            data[0] = 6
            data[1] = hub
            data[2] = RequestType.portModeInformation.rawValue
            data[3] = portId
            data[4] = mode
            data[5] = requestType.rawValue
            return Request(hub: hub, data: data, type: .portModeInformation, body: body)
        case .firmwareUpdateGoIntoBootMode:
            let safeString = "LPF2-Boot".utf8.map { UInt8($0) }
            var data = [UInt8](repeating: 0, count: safeString.count + 3)
            data[0] = UInt8(safeString.count + 3)
            data[1] = hub
            data[2] = RequestType.firmwareUpdateGoIntoBootMode.rawValue
            for i in 0 ..< safeString.count {
                data[i + 3] = safeString[i]
            }
            return Request(hub: hub, data: data, type: .firmwareUpdateGoIntoBootMode, body: body)
        case .firmwareUpdateLockMemory:
            let safeString = "Lock-Mem".utf8.map { UInt8($0) }
            var data = [UInt8](repeating: 0, count: safeString.count + 3)
            data[0] = UInt8(safeString.count + 3)
            data[1] = hub
            data[2] = RequestType.firmwareUpdateLockMemory.rawValue
            for i in 0 ..< safeString.count {
                data[i + 3] = safeString[i]
            }
            return Request(hub: hub, data: data, type: .firmwareUpdateLockMemory, body: body)
        case .firmwareUpdateLockStatus:
            var data = [UInt8](repeating: 0, count: 3)
            data[0] = 3
            data[1] = hub
            data[2] = RequestType.firmwareUpdateLockStatus.rawValue
            return Request(hub: hub, data: data, type: .firmwareUpdateLockStatus, body: body)
        case .virtualPortSetupRequest(request: let request):
            let requestData = request.encode()
            var data = [UInt8](repeating: 0, count: requestData.count + 3)
            data[0] = UInt8(requestData.count + 3)
            data[1] = hub
            data[2] = RequestType.virtualPortSetup.rawValue
            for i in 0 ..< requestData.count {
                data[i + 3] = requestData[i]
            }
            return Request(hub: hub, data: data, type: .virtualPortSetup, body: body)
        case .portInputFormatSetupSingle(portId: let portId, mode: let mode, delta: let interval, notify: let notification):
            var result = [UInt8](repeating: 0, count: 10)
            result[0] = 10
            result[1] = hub
            result[2] = RequestType.portInputFormatSetupSingle.rawValue
            result[3] = portId
            result[4] = mode
            result[5] = UInt8(interval & 0xFF)
            result[6] = UInt8((interval >> 8) & 0xFF)
            result[7] = UInt8((interval >> 16) & 0xFF)
            result[8] = UInt8((interval >> 24) & 0xFF)
            result[9] = notification ? 1 : 0
            return Request(hub: hub, data: result, type: .portInputFormatSetupSingle, body: body)
        case .portInputFormatSetupCombined(portId: let portId, request: let request):
            let requestData = request.encode()
            var data = [UInt8](repeating: 0, count: requestData.count + 4)
            data[0] = UInt8(requestData.count + 4)
            data[1] = hub
            data[2] = RequestType.portInputFormatSetupCombined.rawValue
            data[3] = portId
            for i in 0 ..< requestData.count {
                data[i + 4] = requestData[i]
            }
            return Request(hub: hub, data: data, type: .portInputFormatSetupCombined, body: body)
        case .portOutputCommand(portId: let portId, flags: let flags, request: let request):
            let requestData = request.encode()
            var data = [UInt8](repeating: 0, count: requestData.count + 5)
            data[0] = UInt8(requestData.count + 5)
            data[1] = hub
            data[2] = RequestType.portOutputCommand.rawValue
            data[3] = portId
            for flag in flags {
                data[4] |= flag.rawValue
            }
            for i in 0 ..< requestData.count {
                data[i + 5] = requestData[i]
            }
            return Request(hub: hub, data: data, type: .portOutputCommand, body: body)
        }
    }
}

/// The class that decodes incoming messages.
public class ResponseDecoder {
    
    /// The buffer to handle messages that are split across changes signaled by the characteristic.
    /// (While it is technically possible that messages are fragmented, I did not see this in practice.)
    var buffer: [UInt8] = []
    
    /// Resets the buffer.
    public func reset() {
        buffer = []
    }
    
    /// Decodes the message into a set of responses.
    ///
    /// - parameter data The data to decode.
    /// - returns The responses.
    public func decode(data: Data) -> [Response] {
        // append data to local buffer
        var copy = [UInt8](repeating: 0, count: buffer.count + data.count)
        copy.withUnsafeMutableBytes {
            ptrBuffer in
            buffer.copyBytes(to: ptrBuffer)
            let ptrData = UnsafeMutableRawBufferPointer(start: ptrBuffer.baseAddress! + buffer.count, count: data.count)
            data.copyBytes(to: ptrData)
            return
        }
        buffer = copy
        // process messages contained in buffer
        var result: [Response] = []
        var next = decodeResponse()
        while (next != nil) {
            result.append(next!)
            next = decodeResponse()
        }
        return result
    }
    
    /// Decodes a signle response.
    ///
    /// - returns The response.
    func decodeResponse() -> Response? {
        // read message length
        var length = 0
        var offset = 0
        if buffer.count < 1 {
            return nil
        } else if buffer[0] <= 127 {
            length = Int(buffer[0])
            offset = 1
        } else {
            if buffer.count < 2 {
                return nil
            } else {
                length = Int(buffer[0] & 0x7F) << 8 | Int(buffer[1]) + 127
                offset = 2
            }
        }
        if (buffer.count < length) {
            return nil
        }
        // split buffer
        var data = [UInt8](repeating: 0, count: length)
        data.withUnsafeMutableBufferPointer {
            ptr in
            buffer.copyBytes(to: ptr)
            return
        }
        var remainder = [UInt8](repeating: 0, count: buffer.count - length)
        remainder.withUnsafeMutableBufferPointer {
            ptr in
            buffer.copyBytes(to: ptr, from: length...buffer.count)
        }
        buffer = remainder
        let hub = data[offset]
        if let type = ResponseType(rawValue: data[offset + 1]) {
            let message = decodeResponseBody(data: data, offset: offset + 2, type: type)
            return Response(hub: hub, data: data, type: type, body: message)
        } else {
            // ignore unknown message type and recurse
            return decodeResponse()
        }
    }
    
    /// Decodes a response body at a particular offset.
    ///
    /// - parameter data The data.
    /// - parameter offset The offset to start from.
    /// - parameter type The response type.
    /// - returns The decoded response body.
    func decodeResponseBody(data: [UInt8], offset: Int, type: ResponseType) -> ResponseBody {
        switch type {
        case .hubProperties:
            if data[offset + 1] == 0x06, let property = PropertyType(rawValue: data[offset]) {
                var value = [UInt8](repeating: 0, count: data.count - offset - 2)
                for i in 0..<value.count {
                    value[i] = data[offset + i]
                }
                if let update = PropertyUpdate.decode(type: property, value: value) {
                    return .hubPropertyUpdate(type: property, value: value, update: update)
                }
            }
        case .hubActions:
            if let update = ActionUpdate(rawValue: data[offset]) {
                return .hubActionUpdate(update: update)
            }
        case .hubAttachedIo:
            if let event = IoType(rawValue: data[offset + 1]) {
                var remainder = [UInt8](repeating: 0, count: data.count - offset - 2)
                for i in 0..<remainder.count {
                    remainder[i] = data[offset + 2 + i]
                }
                if let update = IoUpdate.decode(type: event, data: remainder) {
                    return .hubAttachedIo(portId: data[offset], update: update)
                }
            }
        case .hubAlerts:
            if data[offset + 1] == 0x04, let alert = AlertType(rawValue: data[offset]) {
                return .hubAlertUpdate(type: alert, value: data[offset + 2] == 255)
            }
        case .hubFeedback:
            if let update = FeedbackUpdate.decode(type: data[offset + 1]) {
                return .hubFeedback(command: data[offset], update: update)

            }
        case .firmwareUpdateLockStatus:
            return .firmwareUpdateLockStatus(locked: data[offset] != 0xFF)
        case .portInformation:
            if let infoType = PortInformationType(rawValue: data[offset + 1]) {
                let portId = data[offset]
                var remainder = [UInt8](repeating: 0, count: data.count - offset - 2)
                for i in 0..<remainder.count {
                    remainder[i] = data[offset + 2 + i]
                }
                if let update = PortInformationUpdate.decode(type: infoType, data: remainder) {
                    return .portInformation(portId: portId, update: update)
                }
            }
        case .portModeInformation:
            let portId = data[offset]
            let mode = data[offset + 1]
            if let infoType = PortModeType(rawValue: data[offset + 2]) {
                var remainder = [UInt8](repeating: 0, count: data.count - offset - 3)
                for i in 0..<remainder.count {
                    remainder[i] = data[offset + 3 + i]
                }
                if let update = PortModeUpdate.decode(type: infoType, data: remainder) {
                    return .portModeInformation(portId: portId, mode: mode, update: update)
                }
            }
        case .portValueSingle:
            let portId = data[offset]
            var remainder = [UInt8](repeating: 0, count: data.count - offset - 1)
            for i in 0..<remainder.count {
                remainder[i] = data[offset + i + 1]
            }
            return .portValueSingle(portId: portId, data: remainder)
        case .portValueCombined:
            let portId = data[offset]
            let modeValues = (UInt16(data[offset + 1]) << 8) | UInt16(data[offset + 2])
            var modes: [UInt8] = []
            for i in 0..<16 {
                if modeValues & UInt16(1 << i) == UInt16(1 << i) {
                    modes.append(UInt8(i))
                }
            }
            var remainder = [UInt8](repeating: 0, count: data.count - offset - 3)
            for i in 0..<remainder.count {
                remainder[i] = data[offset + 3 + i]
            }
            return .portValueCombined(portId: portId, modes: modes, data: remainder)
        case .portInputFormatSingle:
            let portId = data[offset]
            let mode = data[offset + 1]
            let delta = (UInt32(data[offset + 5]) << 24) | (UInt32(data[offset + 4]) << 16) | (UInt32(data[offset + 3]) << 8) | UInt32(data[offset + 2])
            let enabled = data[offset + 6] == 1
            return .portInputFormatSingle(portId: portId, mode: mode, delta: delta, notify: enabled)
        case .portInputFormatCombined:
            let portId = data[offset]
            let control = data[offset + 1]
            let dataset = (UInt16(data[offset + 3]) << 8) | UInt16(data[offset + 2])
            var combination: [UInt8] = []
            for i in 0..<16 {
                if dataset & UInt16(1 << i) == UInt16(1 << i) {
                    combination.append(UInt8(i))
                }
            }
            return .portInputFormatCombined(portId: portId, control: control, combination: combination)
        case .portOutputCommand:
            var states: [PortOutputState] = []
            for i in stride(from: offset, to: data.count, by: 2) {
                states.append(PortOutputState(portId: data[i], state: data[i + 1]))
            }
            return .portOutputCommand(states: states)
        case .hardwareNetworkCommands:
            if let networkType = NetworkReponse(rawValue: data[offset]) {
                var remainder = [UInt8](repeating: 0, count: data.count - offset - 1)
                for i in 0..<remainder.count {
                    remainder[i] = data[offset + 1 + i]
                }
                if let update = NetworkUpdate.decode(type: networkType, data: remainder) {
                    return .hardwareNetworkUpdate(update: update);
                }
            }
        }
        return .unknown
    }
    
}
