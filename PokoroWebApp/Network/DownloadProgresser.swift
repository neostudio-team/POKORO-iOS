//
//  DownloadProgresser.swift
//  Neonotes2
//
//  Created by Sang Nam on 11/10/2022.
//  Copyright © 2022 Aram Moon. All rights reserved.
//

import Foundation

class DownloadProgresser: NSObject, URLSessionDownloadDelegate {
    
    typealias ProgressBlock = ((Float)->Void)
    typealias CompletionBlock = ((Error?, Data?)->Void)
    
    private var downloadTask: URLSessionDownloadTask?
    private var progressBlock: ProgressBlock?
    private var completionBlock: CompletionBlock?
    
    
    init(urlString: String,
         progess: ProgressBlock?,
         completion: CompletionBlock?) {
        
        super.init()
        self.progressBlock = progess
        self.completionBlock = completion
        
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let url = URL(string: urlString)!
        downloadTask = session.downloadTask(with: url)
    }
    
    func resume() {
        downloadTask?.resume()
    }
    
    func cancel() {
        downloadTask?.cancel()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let data = try? Data(contentsOf: location)
        DispatchQueue.main.async {
            self.completionBlock?(nil, data)
        }
    }
    
    func urlSession(_ session: URLSession,
                    didBecomeInvalidWithError error: Error?) {
        DispatchQueue.main.async {
            self.completionBlock?(error, nil)
        }
    }
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        
        let progress = min(Float(totalBytesWritten) / Float(max(totalBytesExpectedToWrite, 1)), 1)
        DispatchQueue.main.async {
            self.progressBlock?(progress)
        }
    }
    
}
