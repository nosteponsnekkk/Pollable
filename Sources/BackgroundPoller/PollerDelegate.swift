//
//  PollerDelegate.swift
//  
//
//  Created by Oleg on 12.02.2025.
//

import Foundation
public protocol PollerDelegate: AnyObject {
    associatedtype T: Pollable
    func pollingDidFinish(result: T?)
}
