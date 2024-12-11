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
    
    private var connectionTimer: Timer?
    
    init(ssid: String!, passphrase: String!, threadOpetationalDataset: Data!, step1Failed: Bool = false, espDevice: ESPDevice!) {
        self.ssid = ssid
        self.passphrase = passphrase
        self.threadOpetationalDataset = threadOpetationalDataset
        self.espDevice = espDevice
    }
    
    func startProvisioning(completion:((_ status: ESPProvisionStatus, _ failCode: Int?) -> (Void))?) {
        
        print("connectionTimer initiated")
        connectionTimer?.invalidate()
        connectionTimer = Timer.init(timeInterval: 120.0, repeats: false, block: { [weak self] timer in
            
            print("connectionTimer fired")
            self?.connectionTimer?.invalidate()
            
            // need to call completion
            completion?(.failure(.unknownError), 3)
        })
        RunLoop.main.add(connectionTimer!, forMode: .common)
        
        espDevice.provision(ssid: self.ssid, passPhrase: self.passphrase, threadOperationalDataset: self.threadOpetationalDataset) { status in
            
            DispatchQueue.main.async {
                
                var code: Int?
                
                switch status {
                case .success:
                    print("Device has been successfully provisioned!")
                    self.connectionTimer?.invalidate()
                    completion?(status, nil)
                case let .failure(error):
                    switch error {
                        
                    case .wifiStatusAuthenticationError:
                        code = 0
                    case .wifiStatusNetworkNotFound:
                        code = 1
                    case .wifiStatusDisconnected:
                        code = 2
                    
                    case .configurationError:
                        print("Failed to apply network configuration to device")
                        code = 3
                    case .sessionError:
                        print("Session is not established")
                        code = 3
                    default:
                        print("step2FailedWithMessage")
                        code = 3
                    }
                    self.connectionTimer?.invalidate()
                    completion?(status, code)
                    
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
