//
//  Fetchable.swift
//  Neonotes2
//
//  Created by Sang Nam on 11/10/2022.
//  Copyright © 2022 Aram Moon. All rights reserved.
//

import Foundation
import Combine

protocol Fetchable: Requestable {
    associatedtype Response: Decodable
    static var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy { get }
    static var dataDecodingStrategy: JSONDecoder.DataDecodingStrategy { get }
    static var keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy { get }
}

extension Fetchable {
    static var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy {
        return .deferredToDate
    }
    
    static var dataDecodingStrategy: JSONDecoder.DataDecodingStrategy {
        return .deferredToData
    }
    
    static var keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy {
        return .useDefaultKeys
    }
}

extension Fetchable {
    static func decode<T: Decodable>(_ data: Data) -> AnyPublisher<T, RequestableError> {
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = dataDecodingStrategy
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.keyDecodingStrategy = keyDecodingStrategy
        
        
        if T.self is String.Type {
            let str = String(decoding: data, as: UTF8.self)
            return Just(str as! T)
                .setFailureType(to: RequestableError.self)
                .eraseToAnyPublisher()
        }
        
        if data.isEmpty {
            return Empty()
                .setFailureType(to: RequestableError.self)
                .eraseToAnyPublisher()
        }
        
        return Just(data)
            .decode(type: T.self, decoder: decoder)
            .mapError { error in
                if let error = error as? DecodingError {
                    var errorToReport = error.localizedDescription
                    switch error {
                    case .dataCorrupted(let context):
                        let details = context.underlyingError?.localizedDescription ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
                        errorToReport = "\(context.debugDescription) - (\(details))"
                    case .keyNotFound(let key, let context):
                        let details = context.underlyingError?.localizedDescription ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
                        errorToReport = "\(context.debugDescription) (key: \(key), \(details))"
                    case .typeMismatch(let type, let context), .valueNotFound(let type, let context):
                        let details = context.underlyingError?.localizedDescription ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
                        errorToReport = "\(context.debugDescription) (type: \(type), \(details))"
                    @unknown default:
                        break
                    }
                    print("Error: \(errorToReport)")
                    // SNLogger.write(// SNLogger.Log(text: "[Decoding Error]: \(errorToReport)"))
                    return RequestableError.decoding(error: error, data: data)
                }  else {
                    print("Error: \(error.localizedDescription)")
                    // SNLogger.write(// SNLogger.Log(text: "[Decoding Error]: \(error.localizedDescription)"))
                    return RequestableError.underlying(error: error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    static func decodeDR<T: Decodable>(_ data: Data, _ response: URLResponse) -> AnyPublisher<(T, URLResponse), RequestableError> {
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = dataDecodingStrategy
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.keyDecodingStrategy = keyDecodingStrategy
        
        
        if T.self is String.Type {
            let str = String(decoding: data, as: UTF8.self)
            return Just((str as! T, response))
                .setFailureType(to: RequestableError.self)
                .eraseToAnyPublisher()
        }
        
        if data.isEmpty {
            return Empty()
                .setFailureType(to: RequestableError.self)
                .eraseToAnyPublisher()
        }
        
        return Just(data)
            .decode(type: T.self, decoder: decoder)
            .mapError { error in
                if let error = error as? DecodingError {
                    var errorToReport = error.localizedDescription
                    switch error {
                    case .dataCorrupted(let context):
                        let details = context.underlyingError?.localizedDescription ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
                        errorToReport = "\(context.debugDescription) - (\(details))"
                    case .keyNotFound(let key, let context):
                        let details = context.underlyingError?.localizedDescription ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
                        errorToReport = "\(context.debugDescription) (key: \(key), \(details))"
                    case .typeMismatch(let type, let context), .valueNotFound(let type, let context):
                        let details = context.underlyingError?.localizedDescription ?? context.codingPath.map { $0.stringValue }.joined(separator: ".")
                        errorToReport = "\(context.debugDescription) (type: \(type), \(details))"
                    @unknown default:
                        break
                    }
                    print("Error: \(errorToReport)")
                    // SNLogger.write(// SNLogger.Log(text: "[Decoding Error]: \(errorToReport)"))
                    return RequestableError.decoding(error: error, data: data)
                }  else {
                    print("Error: \(error.localizedDescription)")
                    // SNLogger.write(// SNLogger.Log(text: "[Decoding Error]: \(error.localizedDescription)"))
                    return RequestableError.underlying(error: error)
                }
            }
            .flatMap { res in
                Just((res, response))
                    .setFailureType(to: RequestableError.self)
            }
            .eraseToAnyPublisher()
    }
    
    static func fetch(path: Path,
                     parameters: Parameter? = nil,
                     httpHeaderParameters: HttpHeaderParameter? = nil,
                     queryParameters: QueryParameter? = nil) -> AnyPublisher<Response, RequestableError>
    {
        request(path: path,
                parameters: parameters,
                httpHeaderParameters: httpHeaderParameters,
                queryParameters: queryParameters)
            .flatMap(maxPublishers: .max(1)) { dr in
                decode(dr.data)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    static func fetchDR(path: Path,
                     parameters: Parameter? = nil,
                     httpHeaderParameters: HttpHeaderParameter? = nil,
                     queryParameters: QueryParameter? = nil) -> AnyPublisher<(Response, URLResponse), RequestableError>
    {
        request(path: path,
                parameters: parameters,
                httpHeaderParameters: httpHeaderParameters,
                queryParameters: queryParameters)
            .flatMap(maxPublishers: .max(1)) { dr in
                decodeDR(dr.data, dr.response)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
}

