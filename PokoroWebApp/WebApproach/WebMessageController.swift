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
        case connectPokoro, disconnectPokoro, startWifiScan, wifiInputPassword(data: WifiInputPasswordData), startLogin(url: URL)
    }
    
    private var state = State.initiated
    
    weak var delegate: PokoroWebViewSendingDelegate?
    
    private var bleConnectorForWeb = BLEConnectorForWeb()
    private var wifiConnector: WifiConnector?
    
    func messageReceived(_ message: ReceivedMessage) {
        switch message {
        case .startLogin(let url):
            // 1 simply call delegate function so that the webview handles that
            doForStartLogin(url: url)
            
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
        }
    }
    
    private func doForStartLogin(url: URL) {
        self.delegate?.updateWebviewUrlForOAuth(url: url, sender: self)
    }
    
    private func doForConnectPokoro() {
        bleConnectorForWeb.startScan { [weak self] isSucceeded in
            
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if isSucceeded {
                    self.delegate?.sendConnected(sender: self)
                    self.state = .connected(wifiList: [PokoroWifiData]())
                } else {
                    self.delegate?.sendConnectFailed(sender: self)
                }
            }
            
        }
        
    }
    
    private func doForDisconnectPokoro() {
        
        self.bleConnectorForWeb.disConnect()
        self.delegate?.sendDisconnected(sender: self)
        
        self.state = .initiated
        
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
        connector.startProvisioning { [weak self] status in
            
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                
                switch status {
                case .success:
                    self.delegate?.sendWifiConnected(sender: self)
                    self.state = .initiated
                    
                case .failure(let error):
                    self.delegate?.sendWifiConnectFailed(msg: "", sender: self)
                    
                default:
                    break
                }
            }
        }
    }
}
