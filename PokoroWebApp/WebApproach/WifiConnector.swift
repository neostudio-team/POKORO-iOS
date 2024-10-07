//
//  ProvisionMaker.swift
//  PokoroConnectApp
//
//  Copyright (c) 2024 NeoLAB Convergence. All rights reserved.
//

import Foundation
import ESPProvision

class WifiConnector {
    var ssid: String!
    var passphrase: String!
    var threadOpetationalDataset: Data!
    var espDevice: ESPDevice!
    
    init(ssid: String!, passphrase: String!, threadOpetationalDataset: Data!, step1Failed: Bool = false, espDevice: ESPDevice!) {
        self.ssid = ssid
        self.passphrase = passphrase
        self.threadOpetationalDataset = threadOpetationalDataset
        self.espDevice = espDevice
    }
    
    func startProvisioning(completion:((_ status: ESPProvisionStatus) -> (Void))?) {
        
        espDevice.provision(ssid: self.ssid, passPhrase: self.passphrase, threadOperationalDataset: self.threadOpetationalDataset) { status in
            
            DispatchQueue.main.async {
                
                switch status {
                case .success:
                    print("Device has been successfully provisioned!")
                    completion?(status)
                case let .failure(error):
                    switch error {
                    case .configurationError:
                        print("Failed to apply network configuration to device")
                    case .sessionError:
                        print("Session is not established")
                    case .wifiStatusDisconnected:
                        print("wifiStatusDisconnected")
                    default:
                        print("step2FailedWithMessage")
                    }
                    completion?(status)
                    
                case .configApplied:
                    print(".configApplied")
                }
                
            }
        }
    }
    
    private var sceneDelegate: SceneDelegate? {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = scene.delegate as? SceneDelegate {
            return sceneDelegate
        }
        
        return nil
    }
}
