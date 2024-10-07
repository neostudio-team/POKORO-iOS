//
//  Requestable+Loading.swift
//  Neonotes2
//
//  Created by Sang Nam on 11/10/2022.
//  Copyright © 2022 Aram Moon. All rights reserved.
//

import Foundation
import Combine

struct DataAndResponse {
    var data: Data
    var response: URLResponse
}

extension URLResponse {
    func headerField(forKey key: String) -> String? {
        (self as? HTTPURLResponse)?.allHeaderFields[key] as? String
    }
}

extension NSNotification {
    static let invalidatedToken = NSNotification.Name.init("invalidatedToken")
}

typealias RequestableCompletion = (Result<Data, RequestableError>) -> Void

private extension Requestable {
    
    private static func httpHeaderDictionary(data: Data) throws -> [String: String] {
        let decoded = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = decoded as? [String: String] else {
            throw EncodingError.invalidValue(decoded, .init(codingPath: [],
                                                            debugDescription: "Expected to decode Dictionary<String, String> but found a Dictionary<_, _> instead"))
        }
        return dictionary
    }
    
    private static func queryEncode(data: Data) throws -> [URLQueryItem] {
        let decoded = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = decoded as? [String: Any] else {
            throw EncodingError.invalidValue(decoded, .init(codingPath: [],
                                                            debugDescription: "Expected to decode Dictionary<String, _> but found a Dictionary<_, _> instead"))
        }
        return dictionary.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
    }
    
    private static func bodyEncode(parameters: Parameter,
                                   encoder: JSONEncoder) throws -> Either<Data?, [URLQueryItem]>
    {
        switch parameterEncoding {
        case .formURL:
            let decoded = try JSONSerialization.jsonObject(with: encoder.encode(parameters), options: [])
            guard let dictionary = decoded as? [String: Any] else {
                throw EncodingError.invalidValue(decoded,
                                                 .init(codingPath: [], debugDescription: "Expected to decode Dictionary<String, _> but found a Dictionary<_, _> instead"))
            }
            return .right(dictionary.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) })
        case .json:
            return try .left(encoder.encode(parameters))
        case .xml:
            return .left((parameters as? String)?.data(using: .utf8))
        case let .custom(_, closure):
            return try .left(closure(encoder.encode(parameters)))
        }
    }
    
    static private func makeRequest(pathProvider: PathComponentsProvider,
                                    parameters: Parameter?,
                                    httpHeaderParameters: HttpHeaderParameter?,
                                    queryParameters: QueryParameter?,
                                    token: Token?) throws -> URLRequest {
        guard var urlComponents = URLComponents(string: host) else {
            throw RequestableError.invalidUrl(urlString: host)
        }
        do {
            var requestBody: Data?
            let encoder = JSONEncoder()
            encoder.dataEncodingStrategy = dataEncodingStrategy
            encoder.dateEncodingStrategy = dateEncodingStrategy
            if let parameters = parameters {
                let encoded = try bodyEncode(parameters: parameters, encoder: encoder)
                switch encoded {
                case let .left(data):
                    requestBody = data
                case let .right(items):
                    var components = URLComponents()
                    components.queryItems = items
                    requestBody = components.percentEncodedQuery?.data(using: .utf8)
                }
            }
            if let queryParameters = queryParameters {
                urlComponents.queryItems = try queryEncode(data: encoder.encode(queryParameters))
            }
            guard let baseUrl = urlComponents.url else {
                throw RequestableError.invalidUrl(urlString: pathProvider.pathComponents.joined(separator: "/"))
            }
            let url = pathProvider.pathComponents.reduce(baseUrl, {
                if !$1.isEmpty {
                    return $0.appendingPathComponent($1)
                }
                return $0
            })
            var request = URLRequest(url: url)
            request.cachePolicy = cachePolicy
            request.httpMethod = method.description
            request.httpBody = requestBody
            if let httpHeaderParameters = httpHeaderParameters {
                let httpDictionary = try httpHeaderDictionary(data: encoder.encode(httpHeaderParameters))
                httpDictionary.forEach { key, value in
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            request.setValue(Request.ParameterEncoding.json.contentType, forHTTPHeaderField: "Accept")
            request.setValue(parameterEncoding.contentType, forHTTPHeaderField: "Content-Type")
            guard authorization.setAuthorizationHeader(for: &request, token: token) else {
                throw RequestableError.invalidToken
            }
            return request
        } catch let error as EncodingError {
            throw RequestableError.encoding(error: error)
        } catch {
            throw RequestableError.underlying(error: error)
        }
    }
    
    static private func request(pathProvider: PathComponentsProvider,
                                parameters: Parameter?,
                                httpHeaderParameters: HttpHeaderParameter?,
                                queryParameters: QueryParameter?,
                                multipartsData: Data?,
                                downloadTask: Bool?) -> AnyPublisher<DataAndResponse, RequestableError> {
        
        if authorization == .oauth,
           let authenticator = authenticator {
            return authenticator.validToken(forceRefresh: false)
                .flatMap { token in
                    taskPublisher(pathProvider: pathProvider,
                                  parameters: parameters,
                                  httpHeaderParameters: httpHeaderParameters,
                                  queryParameters: queryParameters,
                                  multipartsData: multipartsData,
                                  downloadTask: downloadTask,
                                  token: token)
                }
                .tryCatch { error -> AnyPublisher<DataAndResponse, RequestableError> in
                    guard error == .invalidToken else {
                        throw error
                    }
                    return authenticator.validToken(forceRefresh: true)
                        .flatMap { token in
                            taskPublisher(pathProvider: pathProvider,
                                          parameters: parameters,
                                          httpHeaderParameters: httpHeaderParameters,
                                          queryParameters: queryParameters,
                                          multipartsData: multipartsData,
                                          downloadTask: downloadTask,
                                          token: token)
                        }
                        .eraseToAnyPublisher()
                }
                .mapError({ error -> RequestableError in
                    if let error = error as? RequestableError {
                        switch error {
                        case .noAppCredential, .refreshTokenExpired:
                            Authenticator.setLogoutReason(.refreshTokenExpired)
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.invalidatedToken, object: nil)
                            }
                        default: break
                        }
                        return error
                    } else {
                        return .underlying(error: error)
                    }
                })
                .eraseToAnyPublisher()
        }
        return taskPublisher(pathProvider: pathProvider,
                             parameters: parameters,
                             httpHeaderParameters: httpHeaderParameters,
                             queryParameters: queryParameters,
                             multipartsData: multipartsData,
                             downloadTask: downloadTask,
                             token: nil)
    }
    
    static func taskPublisher(pathProvider: PathComponentsProvider,
                              parameters: Parameter?,
                              httpHeaderParameters: HttpHeaderParameter?,
                              queryParameters: QueryParameter?,
                              multipartsData: Data?,
                              downloadTask: Bool?,
                              token: Token?) -> AnyPublisher<DataAndResponse, RequestableError>
    {
        guard let request = try? makeRequest(pathProvider: pathProvider,
                                             parameters: parameters,
                                             httpHeaderParameters: httpHeaderParameters,
                                             queryParameters: queryParameters,
                                             token: token)
        else {
            return Fail(error: .invalidUrl(urlString: pathProvider.pathComponents.joined(separator: "/")))
                .eraseToAnyPublisher()
        }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = timeout
//        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        
        if downloadTask == true {
            return handler(for: config)
                .downloadTaskPublisher(for: request)
                .tryMap { data, response in
                    try mapData(request: request, response: response, data: data)
                }
                .mapError { error in
                    mapError(error: error)
                }
                .eraseToAnyPublisher()
        }
        
        return handler(for: config)
            .dataTaskPublisher(for: request)
            .tryMap { data, response in
                try mapData(request: request, response: response, data: data)
            }
            .mapError { error in
                mapError(error: error)
            }
            .eraseToAnyPublisher()
    }
    
    private static func mapData(request: URLRequest, response: URLResponse, data: Data) throws -> DataAndResponse {
        debugPrintYAML(request: request, response: response, received: data)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RequestableError.nonHTTPResponse
        }
        guard validStatusCodes.contains(httpResponse.statusCode) else {
            if [401,403,406].contains(httpResponse.statusCode) &&
                (authorization == .oauth  || authorization == .refresh) {
                Authenticator.setLogoutReason(.invalidToken)
                if httpResponse.statusCode == 406 {
                    Authenticator.setLogoutReason(.loggedInAnotherDevice)
                }
                throw RequestableError.invalidToken
            }
            throw RequestableError.statusCode(code: httpResponse.statusCode, response: httpResponse, data: data)
        }
        return .init(data: data, response: response)
    }
    
    private static func mapError(error: Error) -> RequestableError {
        if let error = error as? RequestableError {
            return error
        } else {
            return .underlying(error: error)
        }
    }
}

extension Requestable {
    static func request(path: Path,
                        parameters: Parameter? = nil,
                        httpHeaderParameters: HttpHeaderParameter? = nil,
                        queryParameters: QueryParameter? = nil,
                        multipartsData: Data? = nil,
                        downloadTask: Bool? = false) -> AnyPublisher<DataAndResponse, RequestableError> {
        return request(pathProvider: path,
                       parameters: parameters,
                       httpHeaderParameters: httpHeaderParameters,
                       queryParameters: queryParameters,
                       multipartsData: multipartsData,
                       downloadTask: downloadTask)
    }
}





extension URLSession {
    
    public func downloadTaskPublisher(for url: URL) -> URLSession.DownloadTaskPublisher {
        self.downloadTaskPublisher(for: .init(url: url))
    }
    
    public func downloadTaskPublisher(for request: URLRequest) -> URLSession.DownloadTaskPublisher {
        .init(request: request, session: self)
    }
    
    public struct DownloadTaskPublisher: Publisher {
        
        public typealias Output = (data: Data, response: URLResponse)
        public typealias Failure = URLError
        
        public let request: URLRequest
        public let session: URLSession
        
        public init(request: URLRequest, session: URLSession) {
            self.request = request
            self.session = session
        }
        
        public func receive<S>(subscriber: S) where S: Subscriber,
                                                    DownloadTaskPublisher.Failure == S.Failure,
                                                    DownloadTaskPublisher.Output == S.Input
        {
            let subscription = DownloadTaskSubscription(subscriber: subscriber, session: session, request: request)
            subscriber.receive(subscription: subscription)
        }
    }
}

extension URLSession {
    
    public func uploadTaskPublisher(for url: URL, multipartsData: Data?) -> URLSession.UploadTaskPublisher {
        self.uploadTaskPublisher(for: .init(url: url), multipartsData: multipartsData)
    }
    
    public func uploadTaskPublisher(for request: URLRequest, multipartsData: Data?) -> URLSession.UploadTaskPublisher {
        .init(request: request, session: self, multipartsData: multipartsData)
    }
    
    public struct UploadTaskPublisher: Publisher {
        
        public typealias Output = (data: Data, response: URLResponse)
        public typealias Failure = URLError
        
        public let request: URLRequest
        public let session: URLSession
        public let multipartsData: Data?
        
        public init(request: URLRequest, session: URLSession, multipartsData: Data?) {
            self.request = request
            self.session = session
            self.multipartsData = multipartsData
        }
        
        public func receive<S>(subscriber: S) where S: Subscriber,
                                                    UploadTaskPublisher.Failure == S.Failure,
                                                    UploadTaskPublisher.Output == S.Input
        {
            let subscription = UploadTaskSubscription(subscriber: subscriber, session: session, request: request, multipartsData: self.multipartsData)
            subscriber.receive(subscription: subscription)
        }
    }
}


extension URLSession {
    
    final class DownloadTaskSubscription<SubscriberType: Subscriber>: Subscription where
    SubscriberType.Input == (data: Data, response: URLResponse),
    SubscriberType.Failure == URLError
    {
        private var subscriber: SubscriberType?
        private weak var session: URLSession!
        private var request: URLRequest!
        private var task: URLSessionDownloadTask!
        
        init(subscriber: SubscriberType, session: URLSession, request: URLRequest) {
            self.subscriber = subscriber
            self.session = session
            self.request = request
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else {
                return
            }
            self.task = self.session.downloadTask(with: request) { [weak self] url, response, error in
                if let error = error as? URLError {
                    self?.subscriber?.receive(completion: .failure(error))
                    return
                }
                guard let response = response else {
                    self?.subscriber?.receive(completion: .failure(URLError(.badServerResponse)))
                    return
                }
                guard let url = url else {
                    self?.subscriber?.receive(completion: .failure(URLError(.badURL)))
                    return
                }
                if let data = try? Data(contentsOf: url) {
                    _ = self?.subscriber?.receive((data: data, response: response))
                } else {
                    self?.subscriber?.receive(completion: .failure(URLError(.cannotParseResponse)))
                }
                self?.subscriber?.receive(completion: .finished)
                
            }
            self.task.resume()
        }
        
        func cancel() {
            self.task.cancel()
        }
    }
    
    final class UploadTaskSubscription<SubscriberType: Subscriber>: Subscription where
    SubscriberType.Input == (data: Data, response: URLResponse),
    SubscriberType.Failure == URLError
    {
        private var subscriber: SubscriberType?
        private weak var session: URLSession!
        private var request: URLRequest!
        private var task: URLSessionUploadTask!
        private var multipartsData: Data?
        
        init(subscriber: SubscriberType, session: URLSession, request: URLRequest, multipartsData: Data?) {
            self.subscriber = subscriber
            self.session = session
            self.request = request
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else {
                return
            }
            
            self.task = self.session.uploadTask(with: request, from: multipartsData, completionHandler: { [weak self] data, response, error in
                if let error = error as? URLError {
                    self?.subscriber?.receive(completion: .failure(error))
                    return
                }
                guard let response = response else {
                    self?.subscriber?.receive(completion: .failure(URLError(.badServerResponse)))
                    return
                }
                
                if let data = data {
                    _ = self?.subscriber?.receive((data: data, response: response))
                } else {
                    self?.subscriber?.receive(completion: .failure(URLError(.cannotParseResponse)))
                }
                self?.subscriber?.receive(completion: .finished)
                
            })
            self.task.resume()
        }
        
        func cancel() {
            self.task.cancel()
        }
    }
}


public enum Either<A, B> {
    case left(A)
    case right(B)
    
    public var left: A? {
        switch self {
        case .left(let value):
            return value
        case .right:
            return nil
        }
    }
    
    public var right: B? {
        switch self {
        case .left:
            return nil
        case .right(let value):
            return value
        }
    }
    
    /// Applies the transform function to the `.left` value, if it is set.
    ///
    ///     let e = Either<String, Int>.left("hello")
    ///     let g = e.mapLeft { $0 + " world" }
    ///     let h = g.mapRight { $0 + 1 }
    ///     g == h == .left("hello world")
    ///
    /// - Parameter transform: The transformative function.
    /// - Returns: A transformed `Either`.
    public func mapLeft<R>(_ transform: (A) throws -> R) rethrows -> Either<R, B> {
        switch self {
        case .left(let a):
            return try .left(transform(a))
        case .right(let b):
            return .right(b)
        }
    }
    
    /// Applies the transform function to the `.right` value, if it is set.
    ///
    ///     let e = Either<String, Int>.right(10)
    ///     let g = e.mapLeft { $0 + " world" }
    ///     let h = g.mapRight { $0 + 1 }
    ///     g == h == .right(11)
    ///
    /// - Parameter transform: The transformative function.
    /// - Returns: A transformed `Either`.
    public func mapRight<R>(_ transform: (B) throws -> R) rethrows -> Either<A, R> {
        switch self {
        case .left(let a):
            return .left(a)
        case .right(let b):
            return try .right(transform(b))
        }
    }
    
    /// Applies the transform function to the `.left` value, if it is set.
    ///
    ///     let e = Either<String, Int>.left("hello")
    ///     let g = e.flatMapLeft { .left([$0]) }
    ///     g == .left(["hello"])
    ///
    /// - Parameter transform: The transformative function.
    /// - Returns: A transformed `Either`.
    public func flatMapLeft<R>(_ transform: (A) throws -> Either<R, B>) rethrows -> Either<R, B> {
        switch self {
        case .left(let a):
            return try transform(a)
        case .right(let b):
            return .right(b)
        }
    }
    
    /// Applies the transform function to the `.right` value, if it is set.
    ///
    ///     let e = Either<String, Int>.right(10)
    ///     let g = e.flatMapRight { .left(String($0) + " world") }
    ///     g == .left("10 world")
    ///
    /// - Parameter transform: The transformative function.
    /// - Returns: A transformed `Either`.
    public func flatMapRight<R>(_ transform: (B) throws -> Either<A, R>) rethrows -> Either<A, R> {
        switch self {
        case .left(let a):
            return .left(a)
        case .right(let b):
            return try transform(b)
        }
    }
}

public extension Either where A == B {
    
    /// Consolidate into the underlying concrete type when both types match.
    ///
    ///     let e = Either<String, Int>.right(10)
    ///     let f = e.mapLeft { Int($0) ?? 0 }
    ///     let g = e.mapRight { String($0) + " world" }
    ///     f.consolidated == 10
    ///     g.consolidated == "10 world"
    ///
    /// - Returns: The contained value, whether `.left` or `.right`.
    var consolidated: A {
        switch self {
        case .left(let a):
            return a
        case .right(let b):
            return b
        }
    }
}

extension Either: Equatable where A: Equatable, B: Equatable {
    public static func == (lhs: Either<A, B>, rhs: Either<A, B>) -> Bool {
        switch (lhs, rhs) {
        case (.left(let x), .left(let y)):
            return x == y
        case (.right(let x), .right(let y)):
            return x == y
        default:
            return false
        }
    }
}

extension Either: Decodable where A: Decodable, B: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try (try? container.decode(A.self)).map(Either.left) ?? .right(container.decode(B.self))
    }
}

extension Either: Encodable where A: Encodable, B: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .left(let left):
            try container.encode(left)
        case .right(let right):
            try container.encode(right)
        }
    }
}
