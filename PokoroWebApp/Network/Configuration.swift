//
//  Configuration.swift
//  Neonotes2
//
//  Created by Sang Nam on 11/10/2022.
//  Copyright © 2022 Aram Moon. All rights reserved.
//

import Foundation


enum Configuration {
    static let CLIENT_ID_APPLE = "neolab_neostudio_ios_apple"
    static let CLIENT_ID_GOOGLE = "neolab_neostudio_ios_google"
    static let CLIENT_ID_NEO = "neolab_neostudio_ios"

    static let CLIENT_SECRET_APPLE = "dXhAZn45ELvgu44uD1Q8XcpCAYN4aW5L"
    static let CLIENT_SECRET_GOOGLE = "TJWRKyoprwp5Zpb655a7hwrSzHOtqPA1"
    static let CLIENT_SECRET_NEO = "t13uVSjNsiIxqXYP0Yt5KUNnhIxHyhds"
    
    #if NEO_PROD
    static let USE_PRODUCTION = true
    #else
    static let USE_PRODUCTION = false
    #endif
    
    static var LOGIN_URL: String {
        USE_PRODUCTION
        ? "https://neolabcloudlogin.web.app"
        : "https://neolabcloudlogin-staging.web.app"
    }
    
    static var BASE_URL_ROUTER: String {
        USE_PRODUCTION
        ? "https://router.neolab.net"
        : "https://ndp-dev.onthe.live:5443"
    }
    
    static var BASE_URL_AUTH: String {
        USE_PRODUCTION
        ? "https://auth.neolab.net"
        : "https://ndp-dev.onthe.live:7443"
    }
    
    static var BASE_URL_USER: String {
        USE_PRODUCTION
        ? "https://user.neolab.net"
        : "https://ndp-dev.onthe.live:6443"
    }
    static var BASE_URL_PAPER: String {
        USE_PRODUCTION
        ? "https://paper.neolab.net"
        : "https://ndp-dev.onthe.live:8443"
    }
    
    static var BASE_URL_INK: String {
        USE_PRODUCTION
        ? "https://ink.neolab.net"
        : "https://ndp-dev.onthe.live:9443"
    }
    
    static var BASE_URL_RELAY_API: String {
        USE_PRODUCTION
        ? "https://relay-api.neolab.net"
        : "https://ndp-dev.onthe.live:4443"
    }
    
    static var BASE_URL_RELAY_LIVE: String {
        USE_PRODUCTION
        ? "https://relay-live.neolab.net"
        : "https://ndp-dev.onthe.live:3443"
    }
    
    static var BASE_URL_STORAGE: String {
        USE_PRODUCTION
        ? "https://storage.neolab.net"
        : "https://ndp-dev.onthe.live:2443"
    }
    
    static var BASE_URL_FILE_STORAGE: String {
        USE_PRODUCTION
        ? "https://objectstorage.ap-seoul-1.oraclecloud.com"
        : "https://objectstorage.ap-seoul-1.oraclecloud.com"
    }
    
    static var MINI_APP_URL: String {
        USE_PRODUCTION
        ? "https://neostudio-quickview.web.app"
        : "https://neostudio-quickview-staging.web.app"
    }
    
    static var MINI_APP_ROUTING_PAGE_URL: String {
        USE_PRODUCTION
        ? "https://neostudio-quickview.web.app/routepage"
        : "https://neostudio-quickview-staging.web.app/routepage"
    }
}
