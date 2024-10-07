//
//  AuthService.swift
//  Neonotes2
//
//  Created by Sang Nam on 11/10/2022.
//  Copyright © 2022 Aram Moon. All rights reserved.
//

import Foundation

struct AuthApiTokenHeaderParameter: Codable {
    let authorization: String
    
    enum CodingKeys: String, CodingKey {
        case authorization = "Authorization"
    }
}

struct AuthIntropectHeaderParameter: Codable {
    let contentType = "application/x-www-form-urlencoded"

    enum CodingKeys: String, CodingKey {
        case contentType = "Content-Type"
    }
}

struct StrokePagingHeaderParameter: Codable {
    var contToken: String?

    enum CodingKeys: String, CodingKey {
        case contToken = "Cont-Token"
    }
}




enum AuthService {
    enum GetToken: Fetchable {
        typealias HttpHeaderParameter = AuthApiTokenHeaderParameter
        typealias Response = Authenticator.AppCredential
        
        static let method: Request.Method = .post
        static var authorization: RequestableAuthorization = .refresh
        static let keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase
        static let host: String = Configuration.BASE_URL_AUTH
        
        enum GrantType: String, Codable {
            case authorization_code
            case refresh_token
        }
        
        struct QueryParameter: Encodable {
            let grant_type: GrantType
            var code: String?
            var refresh_token: String?
        }
        
        struct Path: PathComponentsProvider {
            var pathComponents: [String] {
                ["oauth/v2/token"]
            }
        }
    }
    
    enum Introspect: Fetchable {
        typealias HttpHeaderParameter = AuthIntropectHeaderParameter

        static let method: Request.Method = .post
        static let host: String = Configuration.BASE_URL_AUTH
        
        struct Response: Codable {
            var iss: String?
            var active: Bool
        }
        
        struct QueryParameter: Encodable {
            let token: String
        }
        
        struct Path: PathComponentsProvider {
            var pathComponents: [String] {
                ["oauth/v2/introspect"]
            }
        }
    }
}

extension Authenticator.AppCredential {
    var userId: String? {
        guard let jwt = try? DecodedJWT.decode(jwt: accessToken) else { return nil }
        return jwt.subject
    }
    
    var basic: String {
        return Self.basic(clientId: clientId!, clientSecret: clientSecret!)
    }
    
    static func basic(clientId: String, clientSecret: String) -> String {
        let credentialData = "\(clientId):\(clientSecret)".data(using: String.Encoding.utf8)!
        let base64Credentials = credentialData.base64EncodedString(options: [])
        let basic = "Basic \(base64Credentials)"
        return basic
    }
}
