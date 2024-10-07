//
//  Authenticator.swift
//  Neonotes2
//
//  Created by Sang Nam on 11/10/2022.
//  Copyright © 2022 Aram Moon. All rights reserved.
//

import Foundation
import Combine

enum DataError: Error {
    case parsing(description: String)
    case network(description: String)
    case userNotExist
}

protocol AuthenticatorProvider: AnyObject {
    func readCredential() -> Authenticator.AppCredential?
    func saveCredential(_ credential: Authenticator.AppCredential)
    func refreshToken(_ oldCredential: Authenticator.AppCredential) -> AnyPublisher<Authenticator.AppCredential, RequestableError>
}

class Authenticator {

    static let shared = Authenticator()
    var forcedRefresh = false
    private struct Constant {
        static let REFRESH_TOKEN_BEFORE_ACTUAL_EXPIRY_DATE: Double = (10 * 60 * 60) // 10 hr
    }
    
    enum LogoutReason: Int {
        case none = 0
        case invalidToken = 1
        case refreshTokenExpired = 2
        case loggedInAnotherDevice = 3
    }
    
    struct AppCredential: Codable {
        var accessToken: String
        var tokenType: String
        var refreshToken: String
        var expiresIn: Double?
        var scope: String?
        var clientId: String?
        var clientSecret: String?
        var dateExpire: Date?
    }
    
    static private(set) var logoutReason: LogoutReason = .none
    private let queue = DispatchQueue(label: "Authenticator.\(UUID().uuidString)")
    private var refreshPublisher: AnyPublisher<Token, RequestableError>?
    private var credential: AppCredential?
    private var lastRefreshTime: Date?
    private weak var delegate: AuthenticatorProvider?
    
    // MARK: - Init
    func setup(credential: AppCredential?, delegate: AuthenticatorProvider) {
        self.credential = credential
        self.delegate = delegate
        Self.logoutReason = .none
    }
    
    func removeCredential() {
        self.credential = nil
    }
    
    static func setLogoutReason(_ reason: LogoutReason) {
        guard reason.rawValue > Self.logoutReason.rawValue else { return }
        logoutReason = reason
    }
}

extension Authenticator {
    func validToken(forceRefresh: Bool = false) -> AnyPublisher<Token, RequestableError> {
        queue.sync {
            return validToken_(forceRefresh: forceRefresh)
        }
    }
    
    private func validToken_(forceRefresh: Bool = false) -> AnyPublisher<Token, RequestableError> {
        if credential == nil {
            credential = delegate?.readCredential()
        }
        
        guard let credential = credential else {
            return Fail(error: RequestableError.noAppCredential)
                .eraseToAnyPublisher()
        }
        
        let now = Date()
        if let expire = credential.dateExpire,
           expire.timeIntervalSince(now) < Constant.REFRESH_TOKEN_BEFORE_ACTUAL_EXPIRY_DATE {
            return Fail(error: RequestableError.refreshTokenExpired)
                .eraseToAnyPublisher()
        }
    
        if !forceRefresh && !forcedRefresh {
            return Just(credential.accessToken)
                .setFailureType(to: RequestableError.self)
                .eraseToAnyPublisher()
        }
        
        if !forcedRefresh, let lastRefreshTime = lastRefreshTime,
           now.timeIntervalSince(lastRefreshTime) < (30) {
            // SNLogger.write(// SNLogger.Log(text:"[Refresh Token] ignore force refresh as new token already received recently"))
            return Just(credential.accessToken)
                .setFailureType(to: RequestableError.self)
                .eraseToAnyPublisher()
        }
        
        if let publisher = self.refreshPublisher {
            // SNLogger.write(// SNLogger.Log(text: "[Refresh Token] reuse existing refreshPublisher"))
            return publisher
        }
        guard let refreshTokenPublisher = delegate?.refreshToken(credential)
        else {
            return Fail(error: RequestableError.noAppCredential)
                .eraseToAnyPublisher()
        }
        
        forcedRefresh = false
        
        let publisher = refreshTokenPublisher
            .share()
            .handleEvents(receiveOutput: { cred in
                // SNLogger.write(// SNLogger.Log(text: "[Refresh Token] new credential: \(String(describing: cred))"))
                var cred = cred
                cred.dateExpire = credential.dateExpire
                self.lastRefreshTime = Date()
                self.credential = cred
                self.delegate?.saveCredential(cred)
            }, receiveCompletion: { _ in
                // SNLogger.write(// SNLogger.Log(text: "[Refresh Token] refreshPublisher set nil"))
                self.refreshPublisher = nil
            })
            .mapError { error -> RequestableError in
                print("[Refresh Token] Second error: \(error.localizedDescription)")
//                if RequestableError.invalidToken == error {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.invalidatedToken, object: nil)
                    }
//                }
                return error
            }
            .map { response -> Token in
                response.accessToken
            }
            .eraseToAnyPublisher()
        self.refreshPublisher = publisher
        return publisher
    }
}


