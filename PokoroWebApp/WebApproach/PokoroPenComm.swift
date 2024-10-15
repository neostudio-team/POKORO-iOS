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
    
    func setCustomToken(jsonString: String, completion: ((_ isSuccess: Bool) -> (Void))?) {
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            completion?(false)
            return
        }
        
        var tokenArr: [String] = []
        var token_total_size = 0
        var totalTokenCount = 0
        var currTokenIndex = 0
        var refreshToken: String = ""
        
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: Data(jsonString.utf8), options: []) as? [String: Any],
                let payload = jsonObject["payload"] as? [String: Any],
                let tokenStr = payload["token"] as? String,
                let refresh = payload["refreshToken"] as? String {
                    
                    token_total_size = tokenStr.count
                    tokenArr = splitStringByBytes(tokenStr, 140) // Assuming splitStringByBytes function exists
                    totalTokenCount = tokenArr.count
                    currTokenIndex = 0
                    refreshToken = refresh
                }
        } catch {
            print("Failed to parse JSON: \(error)")
            completion?(false)
            return
        }
        
        
        
        
        // nested function
        func sendDataMultipleTimes(tokenIndex: Int, maxAttempts: Int) {
            
            print("sendDataMultipleTimes(tokenIndex: \(tokenIndex), maxAttempts: \(maxAttempts)")
            
            // When
            if currTokenIndex >= maxAttempts {
                
                // TODO: - send auth token to pen
                guard let refreshJsonData = createRefreshTokenJSONData(refreshToken: refreshToken) else {
                    completion?(false)
                    return
                }
                
                device.sendData(path: endpoint, data: refreshJsonData) { responseData, error in
                    
                    if let responseData = responseData,
                       let responseString = String(data: responseData, encoding: .utf8)?.replacingOccurrences(of: "\0", with: ""),
                       let cleanedData = responseString.data(using: .utf8),
                       let jsonObject = try? JSONSerialization.jsonObject(with: cleanedData) as? [String:Any],
                        let status = jsonObject["status"] as? String,
                        status == "success" {
                        
                        completion?(true)
                        return
                        
                    } else {
                        completion?(false)
                        return
                    }
                    
                }
                
                return
            }
            
            // create a json object
            guard let jsonData = createTokenJSONData(token_total_size: token_total_size, currTokenIndex: currTokenIndex, totalTokenCount: totalTokenCount, tokenArr: tokenArr) else {
                completion?(false)
                return
            }
            
            device.sendData(path: endpoint, data: jsonData) { responseData, error in
                
                currTokenIndex += 1
                
                if let responseData = responseData,
                   let responseString = String(data: responseData, encoding: .utf8)?.replacingOccurrences(of: "\0", with: ""),
                   let cleanedData = responseString.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: cleanedData) as? [String:Any],
                    let status = jsonObject["status"] as? String,
                    status == "success" {
                    
                    sendDataMultipleTimes(tokenIndex: currTokenIndex, maxAttempts: totalTokenCount)
                    
                } else {
                    completion?(false)
                    return
                }
                
            }
        }
        
        // Start sending data
        sendDataMultipleTimes(tokenIndex: currTokenIndex, maxAttempts: totalTokenCount)
        
    }
    
    // Assuming you have a helper function like this:
    private func splitStringByBytes(_ str: String, _ byteLimit: Int) -> [String] {
        var parts: [String] = []
        var currentIndex = str.startIndex
        while currentIndex < str.endIndex {
            let endIndex = str.index(currentIndex, offsetBy: byteLimit, limitedBy: str.endIndex) ?? str.endIndex
            let substring = String(str[currentIndex..<endIndex])
            parts.append(substring)
            currentIndex = endIndex
        }
        return parts
    }
    
    private func createTokenJSONData(token_total_size:Int, currTokenIndex:Int, totalTokenCount:Int, tokenArr:[String]) -> Data? {
        var reqToken: [String: Any] = [:]
        var payload: [String: Any] = [:]
        
        do {
            // Add the messageType to reqToken
            reqToken["messageType"] = "POKORO2_Token"
            
            // Add payload details
            payload["token_total_size"] = token_total_size
            payload["index"] = currTokenIndex
            payload["total_index"] = totalTokenCount
            payload["token"] = tokenArr[currTokenIndex]
            
            print("token_total_size: \(token_total_size), index: \(currTokenIndex), total_index:\(totalTokenCount)")
            
            // Attach the payload to reqToken
            reqToken["payload"] = payload
            
            // Convert the dictionary to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: reqToken, options: [])
            
            // Convert JSON data to String
            let str = String(data: jsonData, encoding: .utf8)
            print(str)

            return jsonData
        } catch {
            print("Error creating JSON: \(error)")
            return nil
        }
    }

    private func createRefreshTokenJSONData(refreshToken:String) -> Data? {
        var reqToken: [String: Any] = [:]
        var payload: [String: Any] = [:]
        
        do {
            // Add the messageType
            reqToken["messageType"] = "POKORO2_Auth"
            
            // Add payload details
            payload["refreshToken"] = refreshToken
            
            // Attach the payload to reqToken
            reqToken["payload"] = payload
            
            // Convert the dictionary to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: reqToken, options: [])
            
            // Convert JSON data to String
            let str = String(data: jsonData, encoding: .utf8)
            print(str)

            return jsonData
        } catch {
            print("Error creating JSON: \(error)")
            return nil
        }
    }
}
