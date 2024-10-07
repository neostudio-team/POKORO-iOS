//
//  PathComponentsProvider.swift
//  Neonotes2
//
//  Created by Sang Nam on 11/10/2022.
//  Copyright © 2022 Aram Moon. All rights reserved.
//

import Foundation

protocol PathComponentsProvider {
    var pathComponents: [String] { get }
}

extension String: PathComponentsProvider {
    var pathComponents: [String] {
        return components(separatedBy: "/").filter { !$0.isEmpty }
    }
}

extension Array: PathComponentsProvider {
    var pathComponents: [String] {
        return map(String.init(describing:))
    }
}
