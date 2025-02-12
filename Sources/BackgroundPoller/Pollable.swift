//
//  Pollable.swift
//  
//
//  Created by Oleg on 12.02.2025.
//

import Foundation
public protocol Pollable: Decodable {
    var status: Status { get }
    
}

public enum Status: String, Decodable {
    case processing
    case finished
    case error
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        switch string {
        case "processing", "running":
            self = .processing
        case "finished", "success", "successfull":
            self = .finished
        default:
            self = .error
        }
    }
}
