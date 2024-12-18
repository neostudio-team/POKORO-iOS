//
//  WebMessageController.swift
//  PokoroConnectApp
//
//  Copyright (c) 2024 NeoLAB Convergence. All rights reserved.
//

import UIKit

class WebMessageController: NSObject {
    
    struct PokoroWifiData: Encodable {
        let wifiName: String
        let rssi: Int // signal's strength
        let security: Int // 0 - no password, 1: password
    }
    
    struct WifiInputPasswordData {
        let wifiName: String
        let pw: String
    }
    
    enum State {
        case initiated, connected(wifiList: [PokoroWifiData])
    }
    
    enum ReceivedMessage {
        case stopScan, connectPokoro, disconnectPokoro, startWifiScan, wifiInputPassword(data: WifiInputPasswordData), startLogin(url: URL), callBrowser(url: URL)
        case setCustomSetting(jsonStr: String), setCustomToken(jsonStr: String)
        case reqIsConnectedPokoro
    }
    
    private var state = State.initiated
    
    weak var delegate: PokoroWebViewSendingDelegate?
    
    private var bleConnectorForWeb = BLEConnectorForWeb()
    private var wifiConnector: WifiConnector?
    
    private var penCommManager: PokoroPenCommManager?
    
    override init() {
        super.init()
        
        // register notification
        NotificationCenter.default.addObserver(self, selector: #selector(bleDisconnected(_:)), name: .bleDisConnected, object: nil)
    }
    
    func messageReceived(_ message: ReceivedMessage) {
        switch message {
        case .startLogin(let url):
            // 1 simply call delegate function so that the webview handles that
            doForStartLogin(url: url)
            
        case .stopScan:
            // 1 simply stop bluetooth scan
            doForStopScan()
            
        case .connectPokoro:
            // 1 Use BLEConnector to start Scan
            // 2 Upon completion, send either success or failure message
            // 3 upon success, let state be 'connected'
            doForConnectPokoro()
            
        case .disconnectPokoro:
            // 1 Use BLEConnector to disconnect
            // 2 Send disconnected message
            // 3 let state be 'initiated'
            doForDisconnectPokoro()
            
        case .reqIsConnectedPokoro:
            doForReqIsConnectedPokoro()
            
        case .startWifiScan:
            // 1 if state is 'initiated', send 'WifiScanFailed'
            // 2 else, use device to start provisioning
            // 3 Upon completion, send either success or failure message
            // 4 renew state
            doForStartWifiScan()
            
        case .wifiInputPassword(let data):
            // 1 Use WifiConnector to connect to wifi
            // 2 Upon completion, send either success or failure message
            // 3 Upon success, set state to init
            doForWifiInputPassword(data: data)
            
        case .setCustomSetting(let jsonStr):
            // 1 communicate with the pen to set the value
            // 2 send the result to the web
            doForSetCustomSetting(jsonStr: jsonStr)
        
        case .setCustomToken(let jsonStr):
            // 1 communicate with the pen to set the token value
            // 2 send the result to the web
            doForSetCustomToken(jsonStr: jsonStr)
            
        case .callBrowser(let url):
            doForCallBrowser(url: url)
        }
    }
    
    private func doForStartLogin(url: URL) {
        self.delegate?.updateWebviewUrlForOAuth(url: url, sender: self)
    }
    
    private func doForCallBrowser(url: URL) {
        self.delegate?.openWebPage(url: url, sender: self)
    }
    
    private func doForStopScan() {
        bleConnectorForWeb.stopScan()
    }
    
    private func doForConnectPokoro() {
        bleConnectorForWeb.startScan { [weak self] isSucceeded in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if isSucceeded {
                    self.delegate?.sendConnecting(sender:self)
                }
            }
            
            
        } allCompletion: { [weak self] isSucceeded in
            
            print("allCompletion \(isSucceeded)")
            
            guard let self = self else { return }
            
            print("allCompletion self guard")
            
            if let device = self.bleConnectorForWeb.theDevice {
                penCommManager = PokoroPenCommManager(device: device)
                penCommManager?.askStatus(completion: { response in
                    
                    print("penCommManager?.askStatus(completion: { response in")
                    
                    DispatchQueue.main.async {
                        if let response = response {
                            
                            self.delegate?.sendPokoroStatus(status: response, sender: self)
                            
                        } else {
                            self.failPenConnectAndSendWebMessage()
                        }
                        
                    }
                    
                })
                
            } else {
                print("sendConnectFailed(sender: self)")
                
                DispatchQueue.main.async {
                    self.delegate?.sendConnectFailed(sender: self)
                }
            }
            
        }
        
    }
    
    private func failPenConnectAndSendWebMessage() {
        DispatchQueue.main.async {
            self.bleConnectorForWeb.disConnect()
            self.delegate?.sendConnectFailed(sender: self)
            self.state = .initiated
        }
        
    }
    
    /// in case pokoro2 device is turned off
    @objc func bleDisconnected(_ notification: Notification) {
        doForDisconnectPokoro()
    }
    
    private func doForDisconnectPokoro() {
        
        self.bleConnectorForWeb.disConnect()
        self.delegate?.sendDisconnected(sender: self)
        
        self.state = .initiated
        
    }
    
    private func doForReqIsConnectedPokoro() {
        
        var isConnected = bleConnectorForWeb.theDevice != nil
        self.delegate?.sendIsConnectedPokoro(isConnected, sender: self)
    }
    
    private func doForStartWifiScan() {
        if case .initiated = state {
            // Handle the initiated state
            self.delegate?.sendWifiScanFailed(msg: "", sender: self)
            return
        }
        
        // start wifi scan
        self.bleConnectorForWeb.theDevice?.scanWifiList { [weak self] wifiList, _ in
            
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                
                if let list = wifiList {
                    let wifiDataToSend = list.sorted { $0.rssi > $1.rssi }.map { network in
                        
                        let security = network.auth.rawValue
                        return PokoroWifiData.init(wifiName: network.ssid, rssi: Int(network.rssi), security: security)
                    }
                    
                    self.delegate?.sendWifiScanResult(result: wifiDataToSend, sender: self)
                } else {
                    self.delegate?.sendWifiScanFailed(msg: "", sender: self)
                }
            }
        }
        
    }
    
    private func doForWifiInputPassword(data: WifiInputPasswordData) {
        
        // TODO: - send error message
        guard let theDevice = bleConnectorForWeb.theDevice else {
            return
        }
        
        let connector = WifiConnector.init(ssid: data.wifiName, passphrase: data.pw, threadOpetationalDataset: nil, espDevice: theDevice)
        connector.startProvisioning { [weak self] status, code in
            
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                
                switch status {
                case .success:
                    self.delegate?.sendWifiConnected(sender: self)
                    self.state = .initiated
                
                case .failure(let error):
                    self.delegate?.sendWifiConnectFailed(msg: "\(code ?? 3)", sender: self)
                    
                default:
                    break
                }
            }
        }
    }
    
    private func doForSetCustomSetting(jsonStr: String) {
        if let device = self.penCommManager?.device {
            penCommManager = PokoroPenCommManager(device: device)
            penCommManager?.setCustomSetting(jsonString: jsonStr, completion: { response in
                DispatchQueue.main.async {
                    
                    guard let response = response else {
                        self.failPenConnectAndSendWebMessage()
                        return
                    }
                    
                    self.delegate?.sendCustomSettingResult(result: response, sender: self)
                }
            })
            
        } else {
            failPenConnectAndSendWebMessage()
        }
        
        
    }
    
    private func doForSetCustomToken(jsonStr: String) {
        
        print("doForSetCustomToken(jsonStr: String)")
        
        if let device = self.penCommManager?.device {
            penCommManager = PokoroPenCommManager(device: device)
            
            
            
            penCommManager?.setCustomToken(jsonString: jsonStr, completion: { success in
                DispatchQueue.main.async {
                    
                    if success == false {
                        self.failPenConnectAndSendWebMessage()
                        return
                    }
                    
                    self.delegate?.sendConnected(sender: self)
                    self.state = .connected(wifiList: [PokoroWifiData]())
                    
                }
            })
            
        } else {
            failPenConnectAndSendWebMessage()
        }
    }
}
