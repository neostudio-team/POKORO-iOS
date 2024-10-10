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
import SafariServices

class PokoroWebViewController: UIViewController, WKScriptMessageHandler, WKUIDelegate, ASWebAuthenticationPresentationContextProviding {
    
    private var webView: WKWebView!
    private var auxSafari: ASWebAuthenticationSession?
    
    private let wkUserContentName = "Native"
    
    private var webMessageController = WebMessageController()
    
    private var isHandlingMessage = false
    private var popupWebView: WKWebView!
    
    private var disposables = Set<AnyCancellable>()
    
    private var oAuthMediator: OAuthMediator?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a WKWebView configuration and add message handler
        let contentController = WKUserContentController()
        contentController.add(self, name: wkUserContentName)
        
        let config = WKWebViewConfiguration()
        let processPool1 = WKProcessPool()
        config.userContentController = contentController
        config.processPool = processPool1
        
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
        },
        startlogin: function(url) {
            window.webkit.messageHandlers.Native.postMessage({action: 'startlogin', url: url});
        }
    };
    """
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(script)
        
        webView = WKWebView(frame: self.view.bounds, configuration: config)
//        webView.navigationDelegate = self
        self.view.addSubview(webView)
        
        webView.evaluateJavaScript("navigator.userAgent"){(result, error) in
        let originUserAgent = result as! String
            let agent = originUserAgent + " inApp"
            self.webView.customUserAgent = agent
        }
        
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
                    print("connectPokoro message received")
                    
                } else if messageBody == "disConnectPokoro" {
                    receivedMessage = .disconnectPokoro
                    print("disConnectPokoro message received")
                    
                } else if messageBody == "startWifiScan" {
                    receivedMessage = .startWifiScan
                    print("startWifiScan message received")
                }
                
            } else if let messageBody = message.body as? [String: Any],
                      let action = messageBody["action"] as? String {
                switch action {
                case "wifiInputPassword":
                    if let wifiName = messageBody["wifiName"] as? String,
                       let pw = messageBody["pw"] as? String {
                        
                        receivedMessage = .wifiInputPassword(data: .init(wifiName: wifiName, pw: pw))
                        print("wifiInputPassword message received wifiName:\(wifiName), pw:\(pw)")
                    }
                case "customSendToken":
                    if let jsonStr = messageBody["data"] as? String {
//                        customSendToken(jsonStr: jsonStr)
                        print("customSendToken message received")
                    }
                case "customSendSetting":
                    if let jsonStr = messageBody["data"] as? String {
//                        customSendSetting(jsonStr: jsonStr)
                        print("customSendSetting message received")
                    }
                case "startlogin":
                    if let urlStr = messageBody["url"] as? String,
                       let url = URL.init(string: urlStr) {
                        receivedMessage = .startLogin(url: url)
                      print("startlogin message received")
                    }
                default:
                    break
                }
            }
            
            if let receivedMessage  = receivedMessage {
                isHandlingMessage = true
                webMessageController.messageReceived(receivedMessage)
            }
            
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.view.window!
    }
}

extension PokoroWebViewController {
    static func newInstance() -> PokoroWebViewController {
        let vc = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PokoroWebViewController") as! PokoroWebViewController
        return vc
    }
}


protocol PokoroWebViewSendingDelegate: class {
    
    // MARK: - startLogIn() message is received
    func updateWebviewUrlForOAuth(url: URL, sender: WebMessageController)
    
    
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
    
    func updateWebviewUrlForOAuth(url: URL, sender: WebMessageController) {
        print("updateWebviewUrlForOAuth(url: URL, sender: WebMessageController)")
        
        // instantiate oAuthMediator to make it work
        oAuthMediator = OAuthMediator()
        
        oAuthMediator?.getCodeSuccessClosure = { [weak self] code in
            self?.sendoAuthCode(value: code)
        }
        
        oAuthMediator?.getCodeFailClosure = { [weak self] in
            self?.sendoAuthFailed()
        }
        
        // use ASWebAuthenticationSession for authentication
        let scheme = "auxSafariAuth"
        
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        
        
        /*
        auxSafari = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
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
        
        auxSafari?.prefersEphemeralWebBrowserSession = true
        auxSafari?.presentationContextProvider = self
        auxSafari?.start()
        */
    }
    
    private func sendoAuthCode(value: String) {
        /*
        auxWebView?.navigationDelegate = nil
        if let auxWebView = auxWebView {
            auxWebView.removeFromSuperview()
        }
        auxWebView = nil
        oAuthMediator = nil
        */
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0, execute: {
            // send value and nullify oAuthMediator
            print("sendoAuthCode(value: String, sender: OAuthMediator)")
            
            self.webView.becomeFirstResponder()
            
            let jsWithParam = "javascript:window.onLogin(\(value))"
            self.webView.evaluateJavaScript(jsWithParam) { (result, error) in
                if let error = error {
                    print("Error calling JS: \(error.localizedDescription)")
                }
            }
            
            self.isHandlingMessage = false
        })
        
        
    }
    
    private func sendoAuthFailed() {
        /*
        auxWebView?.navigationDelegate = nil
        if let auxWebView = auxWebView {
            auxWebView.removeFromSuperview()
        }
        auxWebView = nil
        oAuthMediator = nil
        */
        
        // send value and nullify oAuthMediator
        print("sendoAuthFailed(sender: OAuthMediator)")
        
        // Call back a JavaScript function with a parameter
        let jsWithParam = "javascript:window.onLoginFail()"
        webView.evaluateJavaScript(jsWithParam) { (result, error) in
            if let error = error {
                print("Error calling JS: \(error.localizedDescription)")
            }
        }
        
        isHandlingMessage = false
        
        
    }
    
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
                
//                let c = "[{ \"wifiName\": \"HomeWiFi\", \"security\": 1, \"rssi\": -50 }]"
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

