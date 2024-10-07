//
//  PokoroWebViewController.swift
//  PokoroConnectApp
//
//  Copyright (c) 2024 NeoLAB Convergence. All rights reserved.
//

import UIKit
import WebKit
import Combine
import AuthenticationServices

class PokoroWebViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.view.window!
    }
    
    
    private var webView: WKWebView!
    
    private let wkUserContentName = "Native"
    
    private var webMessageController = WebMessageController()
    
    private var isHandlingMessage = false
    private var popupWebView: WKWebView!
    
    private var disposables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        
        // Create a WKWebView configuration and add message handler
        let contentController = WKUserContentController()
        contentController.add(self, name: wkUserContentName)
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences
        
        
        let scriptSource = """
    window.Native = {
        connectPokoro: function() {
            window.webkit.messageHandlers.Native.postMessage('connectPokoro');
        },
        disConnectPokoro: function() {
            window.webkit.messageHandlers.Native.postMessage('disConnectPokoro');
        },
        startWifiScan: function() {
            window.webkit.messageHandlers.Native.postMessage('startWifiScan');
        },
        wifiInputPassword: function(wifiName, pw) {
            window.webkit.messageHandlers.Native.postMessage({action: 'wifiInputPassword', wifiName: wifiName, pw: pw});
        },
        customSendToken: function(jsonStr) {
            window.webkit.messageHandlers.Native.postMessage({action: 'customSendToken', data: jsonStr});
        },
        customSendSetting: function(jsonStr) {
            window.webkit.messageHandlers.Native.postMessage({action: 'customSendSetting', data: jsonStr});
        }
    };
    """
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(script)
        
        webView = WKWebView(frame: self.view.bounds, configuration: config)
        webView.navigationDelegate = self
        self.view.addSubview(webView)
        
        let clientId = Configuration.CLIENT_ID_GOOGLE
        let clientSecret = Configuration.CLIENT_SECRET_GOOGLE
        let host = Configuration.LOGIN_URL
        
//        let url = URL(string:  host + "/?clientId=\(clientId)&type=ios")!
        
        // Load the HTML page
        let request = URLRequest(url: URL.init(string: "https://pokoro-temp.web.app")!)
//        let request = URLRequest(url: url)
//        let request = URLRequest(url: URL.init(string: "http://localhost:3000")!)
        webView.load(request)
        webView.uiDelegate = self
        webMessageController.delegate = self
         
        
    }
    
    override func viewDidLayoutSubviews() {
        webView.frame = self.view.bounds
    }
    
    override func viewDidAppear(_ animated: Bool) {
//        startOAuthLogin()
    }
    /*
    func startOAuthLogin() {
        let authURL = URL(string: "https://ndp-dev.onthe.live:7443/oauth/v2/authorize?client_id=ioted_android_google&response_type=code&scope=openid&redirect_uri=https://pokoro-dev.onthe.live:444/loginCheck.html")!
        
        // Define your app's custom scheme to handle the callback
        let scheme = "myapp"
        
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { callbackURL, error in
            guard error == nil, let callbackURL = callbackURL else {
                // Handle error if any
                print("Authentication failed with error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Extract the authorization code from the callback URL
            if let urlComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
               let queryItems = urlComponents.queryItems,
               let authorizationCode = queryItems.first(where: { $0.name == "code" })?.value {
                print("Authorization Code: \(authorizationCode)")
                // You can now use this authorization code to exchange for tokens
            }
        }
        
        session.presentationContextProvider = self
        session.start()
    }
    
    //MARK: Creating new webView for popup
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        popupWebView = WKWebView(frame: view.bounds, configuration: configuration)
        popupWebView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        popupWebView!.navigationDelegate = self
        popupWebView!.uiDelegate = self
        view.addSubview(popupWebView!)
        return popupWebView!
    }
    //MARK: To close popup
    func webViewDidClose(_ webView: WKWebView) {
        if webView == popupWebView {
            popupWebView?.removeFromSuperview()
            popupWebView = nil
        }
    }
    */
    /*
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let urlString = navigationAction.request.url?.absoluteString ?? ""

        let clientId = Configuration.CLIENT_ID_GOOGLE
        let clientSecret = Configuration.CLIENT_SECRET_GOOGLE
        
        if urlString.contains("ndplogin://") {
            let point = urlString.range(of: "code=")
            if let theRange = point {
                let authCode = urlString.substring(from: theRange.upperBound)
                var basic = Authenticator.AppCredential.basic(clientId: clientId,
                                                              clientSecret: clientSecret)
                
                AuthService.GetToken.fetch(path: .init(),
                                           parameters: nil,
                                           httpHeaderParameters: .init(authorization: basic),
                                           queryParameters: .init(grant_type: .authorization_code,
                                                                 code: authCode))
                    .receive(on: DispatchQueue.main)
                    .sink { _ in
                    } receiveValue: { [weak self] cred in
                        guard let self = self else { return }
                        var auth = cred
                        auth.clientId = clientId
                        auth.clientSecret = clientSecret
//                        AppUserInfo.auth = auth
//                        AppUserInfo.agreedTermsConditions = true
                        
                        if let email = cred.userId {
//                            DBHelper.shared.initUser(email)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now()+1.4) {
//                            LogoutHelper.returnToSplash()
                        }
                    }
                    .store(in: &disposables)
            }
//            self.webView.removeFromSuperview()
            decisionHandler(.allow)
            return
            
        } else {
            decisionHandler(.allow)
            return
        }
    }
*/
    
    // Handle messages received from JavaScript
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        guard isHandlingMessage == false else { return }
        
        if message.name == wkUserContentName {
            
            var receivedMessage: WebMessageController.ReceivedMessage?
            
            if let messageBody = message.body as? String {
                
                
                
                if messageBody == "connectPokoro" {
                    receivedMessage = .connectPokoro
                    
                } else if messageBody == "disConnectPokoro" {
                    receivedMessage = .disconnectPokoro
                    
                } else if messageBody == "startWifiScan" {
                    receivedMessage = .startWifiScan
                    
                }
                
            } else if let messageBody = message.body as? [String: Any],
                      let action = messageBody["action"] as? String {
                switch action {
                case "wifiInputPassword":
                    if let wifiName = messageBody["wifiName"] as? String,
                       let pw = messageBody["pw"] as? String {
                        
                        receivedMessage = .wifiInputPassword(data: .init(wifiName: wifiName, pw: pw))
                    }
                case "customSendToken":
                    if let jsonStr = messageBody["data"] as? String {
//                        customSendToken(jsonStr: jsonStr)
                    }
                case "customSendSetting":
                    if let jsonStr = messageBody["data"] as? String {
//                        customSendSetting(jsonStr: jsonStr)
                    }
                default:
                    break
                }
            }
            
            if let receivedMessage  = receivedMessage {
                isHandlingMessage = true
                webMessageController.messageReceived(receivedMessage)
            }
            
            /*
            if let messageBody = message.body as? [String: Any] {
                print("JavaScript sent a message: \(messageBody)")

                var receivedMessage: WebMessageController.ReceivedMessage?
                
                // parse message and call webMessageController's function to handle message accordingly
                if let command = messageBody["command"] as? String {
                    
                    if command == "connectPokoro" {
                        receivedMessage = .connectPokoro
                        
                    } else if command == "disConnectPokoro" {
                        receivedMessage = .disconnectPokoro
                        
                    } else if command == "startWifiScan" {
                        receivedMessage = .startWifiScan
                        
                    } else if command == "wifiInputPassword" {
                        
                        
                        if let wifiName = messageBody["wifiName"] as? String,
                           let pw = messageBody["pw"] as? String {
                            
                            receivedMessage = .wifiInputPassword(data: .init(wifiName: wifiName, pw: pw))
                        }
                    }
                }
                
                if let receivedMessage  = receivedMessage {
                    isHandlingMessage = true
                    webMessageController.messageReceived(receivedMessage)
                }
                
                
                // Call back a JavaScript function with a parameter
                let jsWithParam = "notifyCallbackWithParameter({\"param1\":\"Value1\", \"param2\":\"Value2\"})"
                webView.evaluateJavaScript(jsWithParam) { (result, error) in
                    if let error = error {
                        print("Error calling JS: \(error.localizedDescription)")
                    }
                }
/*
                // Call a simple JavaScript function without parameter
                let jsWithoutParam = "notifyCallbackFromNative()"
                webView.evaluateJavaScript(jsWithoutParam) { (result, error) in
                    if let error = error {
                        print("Error calling JS: \(error.localizedDescription)")
                    }
                }
 */
            }
             */
        }
    }

}

extension PokoroWebViewController {
    static func newInstance() -> PokoroWebViewController {
        let vc = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PokoroWebViewController") as! PokoroWebViewController
        return vc
    }
}


protocol PokoroWebViewSendingDelegate: class {
    
    // MARK: - connectPokoro() message is received
    func sendConnected(sender: WebMessageController)
    func sendConnectFailed(sender: WebMessageController)
    
    // MARK: - disConnectPokoro() message is received
    func sendDisconnected(sender: WebMessageController)
    
    // MARK: - startWifiScan() message is received
    func sendWifiScanResult(result: [WebMessageController.PokoroWifiData], sender: WebMessageController)
    
    func sendWifiScanFailed(msg: String, sender: WebMessageController)
    
    // MARK: - wifiInputPassword(wifiName: string, pw: string) is received
    func sendWifiConnected(sender: WebMessageController)
    
    func sendWifiConnectFailed(msg: String, sender: WebMessageController)
}

extension PokoroWebViewController: PokoroWebViewSendingDelegate {
    func sendConnected(sender: WebMessageController) {
        
        print("sendConnected(sender: WebMessageController)")
        
        // Call back a JavaScript function with a parameter
        let jsWithParam = "javascript:window.onDeviceConnected()"
        webView.evaluateJavaScript(jsWithParam) { (result, error) in
            if let error = error {
                print("Error calling JS: \(error.localizedDescription)")
            }
        }
        
        isHandlingMessage = false
    }
    
    func sendConnectFailed(sender: WebMessageController) {
        
        print("sendConnectFailed(sender: WebMessageController)")
        
        let jsWithParam = "javascript:window.onDeviceConnectFail()"
        webView.evaluateJavaScript(jsWithParam) { (result, error) in
            if let error = error {
                print("Error calling JS: \(error.localizedDescription)")
            }
        }
        
        isHandlingMessage = false
    }
    
    func sendDisconnected(sender: WebMessageController) {
        
        print("sendDisconnected(sender: WebMessageController)")
        
        let jsWithParam = "javascript:window.onDeviceDisConnected()"
        webView.evaluateJavaScript(jsWithParam) { (result, error) in
            if let error = error {
                print("Error calling JS: \(error.localizedDescription)")
            }
        }
        
        isHandlingMessage = false
    }
    
    func sendWifiScanResult(result: [WebMessageController.PokoroWifiData], sender: WebMessageController) {
        
        print("sendWifiScanResult(result: [WebMessageController.PokoroWifiData], sender: WebMessageController)")
            
            // Encode the array into JSON data
            if let jsonData = try? JSONEncoder().encode(result),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                
                // Prepare the JavaScript call with the escaped JSON string
                /*
                let jsonString = """
                [{"wifiName":"Network1","security":1,"rssi":-45},{"wifiName":"Network2","security":0,"rssi":-60},{"wifiName":"Network3","security":1,"rssi":-30}]
                """
                */
                
                let c = "[{ \"wifiName\": \"HomeWiFi\", \"security\": 1, \"rssi\": -50 }]"
                /*
                let a = [
                    { "wifiName": "HomeWiFi", "security": 1, "rssi": -50 },
                    { "wifiName": "OfficeWiFi", "security": 0, "rssi": -70 }
                  ]
                 */

//                let escapedJsonString = jsonString.replacingOccurrences(of: "\"", with: "\\\"")

                let jsCode = "javascript:window.onDeviceWifiScanResult(\(jsonString));"
                
                // Execute the JavaScript code in the web view
                webView.evaluateJavaScript(jsCode) { (result, error) in
                    if let error = error {
                        print("Error calling JS: \(error.localizedDescription)")
                    }
                }
            }
            
            isHandlingMessage = false
    }
    
    func sendWifiScanFailed(msg: String, sender: WebMessageController) {
        
        print("sendWifiScanFailed(msg: String, sender: WebMessageController)")
        
        let jsWithParam = "javascript:window.onDeviceWifiScanFail(\(msg))"
        webView.evaluateJavaScript(jsWithParam) { (result, error) in
            if let error = error {
                print("Error calling JS: \(error.localizedDescription)")
            }
        }
        
        isHandlingMessage = false
    }
    
    func sendWifiConnected(sender: WebMessageController) {
        
        print("sendWifiConnected(sender: WebMessageController)")
        
        let jsWithParam = "javascript:window.onDeviceWifiConnected()"
        webView.evaluateJavaScript(jsWithParam) { (result, error) in
            if let error = error {
                print("Error calling JS: \(error.localizedDescription)")
            }
        }
        
        isHandlingMessage = false
    }
    
    func sendWifiConnectFailed(msg: String, sender: WebMessageController) {
        
        print("sendWifiConnectFailed(msg: String, sender: WebMessageController)")
        
        let jsWithParam = "javascript:window.onDeviceWifiConnectFail(\(msg))"
        webView.evaluateJavaScript(jsWithParam) { (result, error) in
            if let error = error {
                print("Error calling JS: \(error.localizedDescription)")
            }
        }
        
        isHandlingMessage = false
    }
    
    
}
