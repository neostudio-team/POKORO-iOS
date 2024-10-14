//
//  PokoroPenComm.swift
//  PokoroWebApp
//
//  Copyright (c) 2024 NeoLAB Convergence. All rights reserved.
//

import ESPProvision

struct PokoroPenCommManager {
    
    let device: ESPDevice
    let endpoint = "custom-data"
    
    func askStatus(completion: ((_ response: String?) -> (Void))?) {
        
        // Construct the JSON object in Swift
        var jsonObject: [String: Any] = [:]
        jsonObject["messageType"] = "POKORO2_ReqStatus"
        let payLoad: [String: Any] = [:] // Empty payload for now
        jsonObject["payLoad"] = payLoad
        
        let jsonData = try! JSONSerialization.data(withJSONObject: jsonObject, options: [])
        

        device.sendData(path: endpoint, data: jsonData) { responseData, error in
            if let error = error {
                print("Failed to send data: \(error.localizedDescription)")
                completion?(nil)
                return
            }

            if let responseData = responseData,
               let responseStr = String(data: responseData, encoding: .utf8) {
                completion?(responseStr)
                return
            }
            
            completion?(nil)
        }
    }
    
    func setCustomSetting(jsonString: String, completion: ((_ response: String?) -> (Void))?) {
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            completion?(nil)
            return
        }
        
        
        device.sendData(path: endpoint, data: jsonData) { responseData, error in
            if let error = error {
                print("Failed to send data: \(error.localizedDescription)")
                completion?(nil)
                return
            }

            if let responseData = responseData,
               let responseStr = String(data: responseData, encoding: .utf8) {
                completion?(responseStr)
                return
            }
            
            completion?(nil)
        }
        
    }

    private func handleSuccessResponse(_ returnData: Data) {
        
        // Convert byte array (Data) to string
        if let responseStr = String(data: returnData, encoding: .utf8) {
            do {
                // Parse the response JSON
                let jsonObject = try JSONSerialization.jsonObject(with: returnData, options: []) as? [String: Any]
                if let jsonObject = jsonObject {
                    print("CustomEndPoint onSuccess returnData: \(jsonObject)")
                    
                    // Extract the "messageType" key from the JSON
                    if let messageType = jsonObject["messageType"] as? String {
                        print("Message Type: \(messageType)")
                    }
                }
            } catch {
                print("Failed to parse JSON: \(error.localizedDescription)")
            }
        }
        
    }
}
