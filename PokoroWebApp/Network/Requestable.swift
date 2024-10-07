//
//  Requestable.swift
//  Neonotes2
//
//  Created by Sang Nam on 11/10/2022.
//  Copyright © 2022 Aram Moon. All rights reserved.
//

import Foundation
import Combine

enum RequestableError: Error, CustomDebugStringConvertible {
    case unknown
    case noAppCredential
    case invalidToken
    case invalidUrl(urlString: String)
    case encoding(error: EncodingError)
    case decoding(error: DecodingError, data: Data)
    case underlying(error: Error)
    case statusCode(code: Int, response: HTTPURLResponse, data: Data)
    case logicError(key: String, description: String)
    case nonHTTPResponse
    case refreshTokenExpired
    
    var debugDescription: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .noAppCredential:
            return "Could not find valid app credential"
        case .invalidToken:
            return "Invalid Token"
        case .invalidUrl(urlString: let url):
            return "Invalid URL: \(url)"
        case .underlying(error: let error):
            return String(describing: error)
        case .encoding(error: let error):
            return String(describing: error)
        case .decoding(error: let error, data: let data):
            return [String(describing: error), String(data: data, encoding: .utf8).map { "JSON: \($0)" }]
                .compactMap { $0 }
                .joined(separator: ", ")
        case .statusCode(code: _, response: let response, data: let data):
            return [response.description, String(data: data, encoding: .utf8).map { "1JSON: \($0)" }]
                .compactMap { $0 }
                .joined(separator: ", ")
        case .logicError(let key, let description):
            return "\(key): \(description)"
        case .nonHTTPResponse:
            return "Non http response"
        case .refreshTokenExpired:
            return "Refresh token expired"
        }
    }
    
    var displayDescription: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .noAppCredential:
            return "Could not find valid app credential"
        case .invalidToken:
            return "Invalid Token"
        case .invalidUrl(urlString: let url):
            return "Invalid URL: \(url)"
        case .underlying(error: let error):
            return String(describing: error)
        case .encoding(error: _):
            return "Filed to encode data received from the server. please try again."
        case .decoding(error: _, data: _):
            return "Filed to encode data received from the server. please try again."
        case .statusCode(code: _, response: _, data: _):
            return "Bad request. please try again."
        case .logicError(let key, let description):
            return "\(key): \(description)"
        case .nonHTTPResponse:
            return "Non http response"
        case .refreshTokenExpired:
            return "Refresh token expired"
        }
    }
}

extension RequestableError: Equatable {
    static func == (lhs: RequestableError, rhs: RequestableError) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown):
            return true
        case (.invalidToken, .invalidToken):
            return true
        case (.refreshTokenExpired, .refreshTokenExpired):
            return true
        default:
            return false
        }
    }
}

extension Dictionary {
    var asString: String? {
        var message: String = ""
        self.forEach {
            if let key = $0.key as? String,
               let val = $0.value as? String {
                message += "\(key): \(val)\n"
            }
        }
        return message.isEmpty ? nil : message
    }
}

enum Request {
    enum NoParameter: Encodable {
        func encode(to encoder: Encoder) throws {}
    }
    
    enum NoHeader: Encodable {
        func encode(to encoder: Encoder) throws {}
    }
    
    enum ParameterEncoding {
        case formURL
        case json
        case xml
        case custom(contentType: String, transform: (Data) throws -> Data?)

        var contentType: String {
            switch self {
            case .formURL:
                return "application/x-www-form-urlencoded"
            case .json:
                return "application/json"
            case .xml:
                return "application/xml"
            case let .custom(type, _):
                return type
            }
        }
    }
    
    enum Method: String, CustomStringConvertible {
        case get
        case head
        case post
        case put
        case delete
        case patch
        
        var description: String {
            return rawValue.uppercased()
        }
    }
}

struct RequestableGenericResponseError: Decodable, Error, CustomStringConvertible {
    let code: Int
    let status: Int
    let message: String
    let developerMessage: String?

    var description: String {
        "\(status) | \(code) | \(developerMessage ?? message)"
    }
}

enum RequestableAuthorization {
    case none
    case basic
    case oauth
    case refresh

    func setAuthorizationHeader(for request: inout URLRequest, token: Token?) -> Bool {
        let field = "Authorization"
        switch self {
        case .basic:
            guard let tokenValue = token else {
                return false
            }
            request.setValue("Basic \(tokenValue)", forHTTPHeaderField: field)
        case .oauth:
            guard let tokenValue = token else {
                return false
            }
            request.setValue("Bearer \(tokenValue)", forHTTPHeaderField: field)
        case .refresh:
            break
        case .none:
            break
        }
        return true
    }
}

typealias Token = String

protocol Requestable {
    associatedtype HttpHeaderParameter: Encodable = Request.NoHeader
    associatedtype QueryParameter: Encodable = Request.NoParameter
    associatedtype Parameter: Encodable = Request.NoParameter
    associatedtype StatusCodes: Collection where StatusCodes.Iterator.Element == Int
    associatedtype ResponseError: Decodable, Swift.Error, CustomStringConvertible = RequestableGenericResponseError
    associatedtype Path: PathComponentsProvider
    
    static func handler(for configuration: URLSessionConfiguration) -> NetworkHandler
    static var method: Request.Method { get }
    static var cachePolicy: URLRequest.CachePolicy { get }
    static var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy { get }
    static var dataEncodingStrategy: JSONEncoder.DataEncodingStrategy { get }
    static var parameterEncoding: Request.ParameterEncoding { get }
    static var timeout: TimeInterval { get }
    static var validStatusCodes: StatusCodes { get }
    static var host: String { get }
    static var authorization: RequestableAuthorization { get }
    static var debug: Bool { get }
    static var authenticator: Authenticator? { get }
}

extension Requestable {
    static var method: Request.Method {
        return .get
    }
    
    static var debug: Bool {
        guard !Configuration.USE_PRODUCTION else { return false }
        return _isDebugAssertConfiguration()
    }
    
    static var cachePolicy: URLRequest.CachePolicy {
        return .reloadIgnoringLocalAndRemoteCacheData
    }
    
    static func handler(for configuration: URLSessionConfiguration) -> NetworkHandler {
        return URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }
    
    static var parameterEncoding: Request.ParameterEncoding {
        switch method {
        case .post, .put, .patch, .get:
            return .json
        case .head, .delete:
            return .formURL
        }
    }
    
    static var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy {
        return .deferredToDate
    }
    
    static var dataEncodingStrategy: JSONEncoder.DataEncodingStrategy {
        return .deferredToData
    }

    static var timeout: TimeInterval {
        return URLSessionConfiguration.default.timeoutIntervalForResource
    }
    
    static var validStatusCodes: CountableClosedRange<Int> {
        return 200...299
    }
    
    static var authorization: RequestableAuthorization {
        return RequestableAuthorization.none
    }
    
    static var host: String {
        return Configuration.BASE_URL_AUTH
    }
    
    static var authenticator: Authenticator? {
        return Authenticator.shared
    }
}
