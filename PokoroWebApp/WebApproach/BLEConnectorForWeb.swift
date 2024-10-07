//
//  BLEConnectorForWeb.swift
//  PokoroConnectApp
//
//  Copyright (c) 2024 NeoLAB Convergence. All rights reserved.
//

import CoreBluetooth
import Foundation

import ESPProvision
import Combine

class BLEConnectorForWeb: ESPDeviceConnectionDelegate {
    func getProofOfPossesion(forDevice: ESPDevice, completionHandler: @escaping (String) -> Void) {
        completionHandler("abcd1234")
    }
    
    func getUsername(forDevice: ESPDevice, completionHandler: @escaping (String?) -> Void) {
        
    }
    
    private let prefix: String = "Prov"
    private var bleDevices:[ESPDevice]?
    
    private (set) var theDevice: ESPDevice?
    private var connectionTimer: Timer?
    
    private var completion: ((_ isSucceeded: Bool) -> (Void))?
    
    func startScan(completion: ((_ isSucceeded: Bool) -> (Void))?) {
        
        self.completion = completion
        
//        theDevice?.disconnect()
        scan()
        print("start scan")
    }
    
    func disConnect() {
        theDevice?.disconnect()
    }
    
    private func scan() {
        ESPProvisionManager.shared.searchESPDevices(devicePrefix: prefix, transport: .ble) { [unowned self] bleDevices, error in
            
            self.bleDevices = bleDevices
            
            // try connecting first device
            if let device = bleDevices?.first {
                device.security = .secure2
                
                connectionTimer = Timer.init(timeInterval: 10.0, repeats: false, block: { [weak self] timer in
                    self?.connectionTimer?.invalidate()
                    
                    // need to call completion
                    self?.completion?(false)
                })
                
                
                device.connect(delegate: self) { [weak self] status in
                    
                    self?.connectionTimer?.invalidate()
                    
                    switch status {
                    case .connected:
                        print("succeeded")
                        self?.theDevice = device
                        
                        // need to call completion
                        self?.completion?(true)
                        
                    case let .failedToConnect(error):
                        
                        print("failed")
                        
                        // need to call completion
                        self?.completion?(false)
                        
                    default:
                        print("default")
                        
                        // need to call completion
                        self?.completion?(false)
                    }
                }

            } else {
                
                // need to call completion
                self.completion?(false)
            }
        }
    }
    
}
