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

class BLEConnectorForWeb: ESPDeviceConnectionDelegate, ESPBLEDelegate {
    func peripheralConnected() {
        print("peripheralConnected()")
    }
    
    func peripheralDisconnected(peripheral: CBPeripheral, error: (any Error)?) {
        print("peripheralDisconnected(peripheral: CBPeripheral, error: (any Error)?)")
        NotificationCenter.default.post(name: .bleDisConnected, object: nil)
    }
    
    func peripheralFailedToConnect(peripheral: CBPeripheral?, error: (any Error)?) {
        print("peripheralFailedToConnect(peripheral: CBPeripheral?, error: (any Error)?)")
    }
    
    func getProofOfPossesion(forDevice: ESPDevice, completionHandler: @escaping (String) -> Void) {
        
        if forDevice.name.lowercased().starts(with: prefix2.lowercased()) {
            completionHandler(pin_new)
            return
        }
        
        completionHandler(pin_old)
    }
    
    func getUsername(forDevice: ESPDevice, completionHandler: @escaping (String?) -> Void) {
        
    }
    
    private let prefix1: String = "Prov_"
    private let prefix2: String = "Pokoro2_"
    
    private let pin_old: String = "abcd1234"
    private let pin_new: String = "vhzhfh2#!"
    
    private var bleDevices:[ESPDevice]?
    
    private (set) weak var theDevice: ESPDevice?
    private var connectionTimer: Timer?
    
    private var allCompletion: ((_ isSucceeded: Bool) -> (Void))?
    private var penScanCompletion: ((_ isSucceeded: Bool) -> (Void))?
    
    func startScan(penScanCompletion: ((_ isSucceeded: Bool) -> (Void))?, allCompletion: ((_ isSucceeded: Bool) -> (Void))?) {
        
        self.penScanCompletion = penScanCompletion
        self.allCompletion = allCompletion
        
        scan()
        print("start scan")
    }
    
    func stopScan() {
        ESPProvisionManager.shared.stopScan()
        connectionTimer?.invalidate()
    }
    
    func disConnect() {
        theDevice?.disconnect()
        connectionTimer?.invalidate()
        theDevice = nil
    }
    
    private func scan() {
        ESPProvisionManager.shared.searchESPDevices(devicePrefix: "", transport: .ble) { [unowned self] bleDevices, error in
            
            bleDevices?.forEach({
                print($0.name)
            })
            
            
            self.bleDevices = bleDevices?.filter({$0.name.lowercased().starts(with: prefix1.lowercased()) || $0.name.lowercased().starts(with: prefix2.lowercased())})
            
            // try connecting first device
            if let device = self.bleDevices?.first {
                device.security = .secure2
                
                connectionTimer?.invalidate()
                
                print("connectionTimer initiated")
                connectionTimer = Timer.init(timeInterval: 5.0, repeats: false, block: { [weak self] timer in
                    
                    print("connectionTimer fired")
                    
                    self?.connectionTimer?.invalidate()
                    
                    // need to call completion
                    self?.allCompletion?(false)
                })
                RunLoop.main.add(connectionTimer!, forMode: .common)
                
                self.penScanCompletion?(true)
                
                device.connect(delegate: self) { [weak self] status in
                    
                    self?.connectionTimer?.invalidate()
                    
                    switch status {
                    case .connected:
                        print("succeeded")
                        self?.theDevice = device
                        self?.theDevice?.bleDelegate = self
                        
                        // need to call completion
                        self?.allCompletion?(true)
                        
                    case let .failedToConnect(error):
                        
                        print("failed")
                        
                        // need to call completion
                        self?.allCompletion?(false)
                        
                    default:
                        print("default")
                        
                        // need to call completion
                        self?.allCompletion?(false)
                    }
                }

            } else {
                
                // need to call completion
                self.allCompletion?(false)
            }
        }
    }
    
}

extension Notification.Name {
    static let bleDisConnected = Notification.Name("bleDisConnected")
}
