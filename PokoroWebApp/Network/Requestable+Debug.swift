//
//  Requestable+Debug.swift
//  Neonotes2
//
//  Created by Sang Nam on 11/10/2022.
//  Copyright © 2022 Aram Moon. All rights reserved.
//

import Foundation

extension Requestable {
    private static func headerTransform(_ header: [AnyHashable: Any]?) -> String {
        return (header ?? [:]).map { "    \($0): \($1)" }.joined(separator: "\n")
    }

    private static func dataTransform(_ data: Data?) -> String {
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "null"
    }
    
    private static func debugYAML(request: URLRequest?) -> String? {
        guard let request = request,
            let method = request.httpMethod,
            let url = request.url
            else { return nil }
        
        #if DEBUG
        return nil
        #endif
        
        
        return """
        Request:
          Method: \(method)
          URL: \(url)
          CachePolicy: \(cachePolicy.rawValue)
          Header:
        \(headerTransform(request.allHTTPHeaderFields))
          Body: \(dataTransform(request.httpBody))
        """
    }
    
    private static func debugCURL(request: URLRequest?) -> String {
        guard let request = request,
              let httpMethod = request.httpMethod,
              let url = request.url,
              let allHTTPHeaderFields = request.allHTTPHeaderFields
        else { return "" }
        let bodyComponents: [String]
        if let data = request.httpBody.flatMap({ String(data: $0, encoding: .utf8) }) {
            if case .formURL = parameterEncoding {
                bodyComponents = data.split(separator: "&").map { "-F \($0)" }
            } else {
                bodyComponents = ["-d", "'\(data.prefix(2000))'"]
            }
        } else {
            bodyComponents = []
        }
        
        func filter(_ key: String, _ value: String) -> String {
            var val = value
            #if DEBUG
            return "\(key): \(val)"
            #else
            if key.lowercased().contains("key") ||
                key.lowercased().contains("x-") ||
                key.lowercased().contains("secret") ||
                key.lowercased().contains("authorization") ||
                value.lowercased().contains("basic") ||
                value.lowercased().contains("bearer") {
                val = "xxxxxxxx"
            }
            return "\(key): \(val)"
            #endif
        }
        let method = "-X \(httpMethod)"
        let headers = allHTTPHeaderFields.map { "-H '\(filter($0.key, $0.value))'" }
        
        return ((["curl", method] + headers + bodyComponents + [url.absoluteString]) as [String])
            .joined(separator: " ")
    }
    
    private static func debugYAML(response: URLResponse?, data: Data?) -> String? {
        guard let response = response as? HTTPURLResponse else { return nil }
        
        #if DEBUG
        return nil
        #endif
        
        return """
        Response:
          Code: \(response.statusCode)
          Header:
        \(headerTransform(response.allHeaderFields))
          Body: \(dataTransform(data))
        """
    }
    
    private static func debugYAML(responseError error: RequestableError?) -> String? {
        guard let error = error else { return nil }
        
        #if DEBUG
        return nil
        #endif
        
        return """
        Response:
          Error: \(error.debugDescription)
        """
    }

    static func debugPrintYAML(request: URLRequest?, response: URLResponse?, received: Data?, error: RequestableError? = nil) {
        guard debug else { return }
        let responseYaml = debugYAML(responseError: error) ?? debugYAML(response: response, data: received)
        let yaml = [debugYAML(request: request), responseYaml]
            .compactMap { $0 }
            .joined(separator: "\n")
        let curl = debugCURL(request: request)
        
        let info = """
        #######################
        ##### Requestable #####
        #######################
        # cURL format:
        # \(curl)
        #######################
        # YAML format:
        \(yaml)
        #######################
        """
        print("\n\(info)\n")
        
        guard let request = request,
            let method = request.httpMethod,
            let url = request.url
            else { return }
        
        if let error = error {
            print("Error: \(error.debugDescription)")
        }
        
    }
}
