//
//  Data + Ext.swift
//
//
//  Created by Oleg on 12.02.2025.
//

import Foundation

extension Data {
    func createTempFile() throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(UUID().uuidString)
        try self.write(to: tempFileURL)
        return tempFileURL
    }
}
