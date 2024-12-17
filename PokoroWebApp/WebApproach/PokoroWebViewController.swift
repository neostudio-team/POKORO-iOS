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
    
//    private var isHandlingMessage = false
    private var popupWebView: WKWebView!
    
    private var disposables = Set<AnyCancellable>()
    
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
        stopScan: function() {
            window.webkit.messageHandlers.Native.postMessage('stopScan');
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
        },
        callBrowser: function(url) {
            window.webkit.messageHandlers.Native.postMessage({action: 'callBrowser', url: url});
        }
    };
    """
        
        
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(script)
        
        webView = WKWebView(frame: self.view.bounds, configuration: config)
//        webView.navigationDelegate = self
        self.view.addSubview(webView)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.evaluateJavaScript("navigator.userAgent"){(result, error) in
        let originUserAgent = result as! String
            let agent = originUserAgent + " inApp"
            self.webView.customUserAgent = agent
        }
        
        // Load the HTML page
//        let request = URLRequest(url: URL.init(string: "https://pokoro-temp.web.app")!)
        
        let request = URLRequest(url: URL.init(string: "https://board.pokoro.ai")!)

//        let request = URLRequest(url: URL.init(string: "https://pokoro-dev.onthe.live")!)
//        let request = URLRequest(url: url)
//        let request = URLRequest(url: URL.init(string: "http://localhost:3000")!)
        webView.load(request)
        webView.uiDelegate = self
        webMessageController.delegate = self
        
    }
    
    override func viewDidLayoutSubviews() {
        
        // Get the safe area insets
        let safeAreaInsets = view.safeAreaInsets
            
        // Apply margin to the top and bottom (e.g., 20 points)
        let topMargin: CGFloat = safeAreaInsets.top
        let bottomMargin: CGFloat = safeAreaInsets.bottom
        
        // Adjust the webView's frame
        webView.frame = CGRect(
            x: 0,
            y: topMargin,  // Respect the top safe area inset
            width: view.bounds.width,
            height: view.bounds.height - topMargin - bottomMargin)
    }
    
    
    // Handle messages received from JavaScript
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
//        guard isHandlingMessage == false else { return }
        
        if message.name == wkUserContentName {
            
            var receivedMessage: WebMessageController.ReceivedMessage?
            
            if let messageBody = message.body as? String {
                
                if messageBody == "connectPokoro" {
                    receivedMessage = .connectPokoro
                    print("connectPokoro message received")
                    
                } else if messageBody == "stopScan" {
                    receivedMessage = .stopScan
                    print("stopScan message received")
                    
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
                        receivedMessage = .setCustomToken(jsonStr: jsonStr)
                        print("customSendToken message received")
                    }
                case "customSendSetting":
                    if let jsonStr = messageBody["data"] as? String {
                        receivedMessage = .setCustomSetting(jsonStr: jsonStr)
                        print("customSendSetting message received")
                    }
                case "startlogin":
                    if let urlStr = messageBody["url"] as? String,
                       let url = URL.init(string: urlStr) {
                        receivedMessage = .startLogin(url: url)
                      print("startlogin message received")
                    }
                case "callBrowser":
                    if let urlStr = messageBody["url"] as? String,
                       let url = URL.init(string: urlStr) {
                        receivedMessage = .callBrowser(url: url)
                      print("startlogin message received")
                    }
                default:
                    break
                }
            }
            
            if let receivedMessage  = receivedMessage {
//                isHandlingMessage = true
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
    func sendConnecting(sender: WebMessageController)
    func sendConnected(sender: WebMessageController)
    func sendConnectFailed(sender: WebMessageController)
    
    // MARK: - disConnectPokoro() message is received
    func sendDisconnected(sender: WebMessageController)
    
    // MARK: - custom data
    func sendPokoroStatus(status:String, sender: WebMessageController)
    func sendCustomSettingResult(result: String, sender: WebMessageController)
    
    // MARK: - startWifiScan() message is received
    func sendWifiScanResult(result: [WebMessageController.PokoroWifiData], sender: WebMessageController)
    
    func sendWifiScanFailed(msg: String, sender: WebMessageController)
    
    // MARK: - wifiInputPassword(wifiName: string, pw: string) is received
    func sendWifiConnected(sender: WebMessageController)
    
    func sendWifiConnectFailed(msg: String, sender: WebMessageController)
    
    // MARK: - openWebPage
    func openWebPage(url: URL, sender: WebMessageController)

}

extension PokoroWebViewController: PokoroWebViewSendingDelegate {
    
    func updateWebviewUrlForOAuth(url: URL, sender: WebMessageController) {
        print("updateWebviewUrlForOAuth(url: URL, sender: WebMessageController)")
        
        
        // use ASWebAuthenticationSession for authentication
        let scheme = "pokorologin"
        
        auxSafari = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] callbackURL, error in
            
            guard error == nil, let callbackURL = callbackURL else {
                // Handle error if any
                print("Authentication failed with error: \(error?.localizedDescription ?? "Unknown error")")
                self?.sendoAuthFailed()
                return
            }
            
            // Extract the authorization code from the callback URL
            if let urlComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
               let queryItems = urlComponents.queryItems,
               let authorizationCode = queryItems.first(where: { $0.name == "code" })?.value {
                print("Authorization Code: \(authorizationCode)")
                // You can now use this authorization code to exchange for tokens
                self?.sendoAuthCode(value: authorizationCode)
            } else {
                self?.sendoAuthFailed()
            }
            
            
            self?.auxSafari = nil
        }
        
        auxSafari?.prefersEphemeralWebBrowserSession = true
        auxSafari?.presentationContextProvider = self
        auxSafari?.start()
        
    }
    
    private func sendoAuthCode(value: String) {
        
        // send value and nullify oAuthMediator
        print("sendoAuthCode(value: String)")
        let jsWithParam = "javascript:window.onLogin(\"\(value)\")"
        send(jsScript: jsWithParam)
//        isHandlingMessage = false
    }
    
    private func sendoAuthFailed() {
        
        // send value and nullify oAuthMediator
        print("sendoAuthFailed()")
        
        // Call back a JavaScript function with a parameter
        let jsWithParam = "javascript:window.onLoginFail()"
        send(jsScript: jsWithParam)
//        isHandlingMessage = false
        
        
    }
    
    func sendConnecting(sender: WebMessageController) {
        print("sendConnecting(sender: WebMessageController)")
        
        // Call back a JavaScript function with a parameter
        let jsWithParam = "javascript:window.onDeviceConnecting()"
        send(jsScript: jsWithParam)
        
        // do not make isHandlingMessage to false
        // sendConnected function call is going to be made instantly that will override
    }
    
    func sendConnected(sender: WebMessageController) {
        
        print("sendConnected(sender: WebMessageController)")
        
        // Call back a JavaScript function with a parameter
        let jsWithParam = "javascript:window.onDeviceConnected()"
        send(jsScript: jsWithParam)
//        isHandlingMessage = false
    }
    
    func sendConnectFailed(sender: WebMessageController) {
        
        print("sendConnectFailed(sender: WebMessageController)")
        
        let jsWithParam = "javascript:window.onDeviceConnectFail()"
        send(jsScript: jsWithParam)
//        isHandlingMessage = false
    }
    
    func sendPokoroStatus(status:String, sender: WebMessageController) {
        
        print("sendPokoroStatus(sender: WebMessageController)")
        
        let cleanedString = status.replacingOccurrences(of: "\0", with: "")
        
        let jsWithParam = "javascript:window.onPokoroStatus('\(cleanedString)')"
        send(jsScript: jsWithParam)
//        isHandlingMessage = false
    }
    
    func sendCustomSettingResult(result: String, sender: WebMessageController) {
        
        print("sendCustomSettingResult(result: String, sender: WebMessageController)")
        
        let cleanedString = result.replacingOccurrences(of: "\0", with: "")
        
        let jsWithParam = "javascript:window.onCustomSendResult('\(cleanedString)')"
        send(jsScript: jsWithParam)
        
    }
    
    func sendDisconnected(sender: WebMessageController) {
        
        print("sendDisconnected(sender: WebMessageController)")
        
        let jsWithParam = "javascript:window.onDeviceDisConnected()"
        send(jsScript: jsWithParam)
//        isHandlingMessage = false
    }
    
    func sendWifiScanResult(result: [WebMessageController.PokoroWifiData], sender: WebMessageController) {
        
        print("sendWifiScanResult(result: [WebMessageController.PokoroWifiData], sender: WebMessageController)")
            
            // Encode the array into JSON data
            if let jsonData = try? JSONEncoder().encode(result),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                
//                let c = "[{ \"wifiName\": \"HomeWiFi\", \"security\": 1, \"rssi\": -50 }]"
                let jsCode = "javascript:window.onDeviceWifiScanResult(\(jsonString));"
                send(jsScript: jsCode)
            }
            
//            isHandlingMessage = false
    }
    
    func sendWifiScanFailed(msg: String, sender: WebMessageController) {
        
        print("sendWifiScanFailed(msg: String, sender: WebMessageController)")
        let jsWithParam = "javascript:window.onDeviceWifiScanFail(\'\(msg)\')"
        send(jsScript: jsWithParam)
//        isHandlingMessage = false
    }
    
    func sendWifiConnected(sender: WebMessageController) {
        
        print("sendWifiConnected(sender: WebMessageController)")
        
        let jsWithParam = "javascript:window.onDeviceWifiConnected()"
        send(jsScript: jsWithParam)
//        isHandlingMessage = false
    }
    
    func sendWifiConnectFailed(msg: String, sender: WebMessageController) {
        
        print("sendWifiConnectFailed(msg: String, sender: WebMessageController)")
        
        let jsWithParam = "javascript:window.onDeviceWifiConnectFail(\'\(msg)\')"
        send(jsScript: jsWithParam)
//        isHandlingMessage = false
    }
    
    func openWebPage(url: URL, sender: WebMessageController) {
        
        let safariVC = SFSafariViewController(url: url)
        safariVC.modalPresentationStyle = .automatic
        self.present(safariVC, animated: true, completion: nil)
    }
    
    private func send(jsScript:String) {
        webView.evaluateJavaScript(jsScript) { (result, error) in
            if let error = error {
                print("Error calling JS: \(error.localizedDescription)")
            }
        }
        
    }
    
}

