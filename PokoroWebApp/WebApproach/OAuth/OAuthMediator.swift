//
//  SignInManager.swift
//  PokoroWebApp
//
//  Copyright (c) 2024 NeoLAB Convergence. All rights reserved.
//

import WebKit

class OAuthMediator: NSObject, WKNavigationDelegate {
    
    var getCodeSuccessClosure: ((_ code: String) -> (Void))?
    var getCodeFailClosure: (() -> (Void))?
    
    private let lastPathComponent = "loginCheck.html"
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let currentURL = webView.url {
            print("Navigated to URL: \(currentURL.absoluteString)")

            
            if isLastPathLoginCheck(from: currentURL.absoluteString) {
                if let code = getCodeValue(from: currentURL.absoluteString) {
                    getCodeSuccessClosure?(code)
                } else {
                    getCodeFailClosure?()
                }
            }
            
        }
    }
    
    private func getCodeValue(from urlString: String) -> String? {
        if let urlComponents = URLComponents(string: urlString) {
            if let queryItems = urlComponents.queryItems {
                for item in queryItems {
                    if item.name == "code" {
                        return item.value
                    }
                }
            }
        }
        return nil
    }
    
    private func isLastPathLoginCheck(from urlString: String) -> Bool {
        if let url = URL(string: urlString) {
            return url.lastPathComponent == lastPathComponent
        }
        return false
    }
}
