//
//  NetworkHandler.swift
//  Neonotes2
//
//  Created by Sang Nam on 11/10/2022.
//  Copyright © 2022 Aram Moon. All rights reserved.
//

import Foundation

protocol NetworkHandler {
    init(configuration: URLSessionConfiguration)
    func dataTaskPublisher(for request: URLRequest) -> URLSession.DataTaskPublisher
    func downloadTaskPublisher(for request: URLRequest) -> URLSession.DownloadTaskPublisher
    func uploadTaskPublisher(for request: URLRequest, multipartsData: Data?) -> URLSession.UploadTaskPublisher
}

extension URLSession: NetworkHandler {}
