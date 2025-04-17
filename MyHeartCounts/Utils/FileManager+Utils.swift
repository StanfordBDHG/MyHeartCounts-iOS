//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import AppleArchive
import Foundation
import System


extension FileManager {
    struct ArchiveOperationError: Error {
        let message: String
        let underlyingError: (any Error)?
        
        init(message: String, underlyingError: (any Error)? = nil) {
            self.message = message
            self.underlyingError = underlyingError
        }
    }
    
    var documentsDirectory: URL {
        URL.documentsDirectory
    }
    
    var sandboxRootDirectory: URL {
        documentsDirectory.deletingLastPathComponent()
    }
    
    var tempDirectory: URL {
        sandboxRootDirectory.appending(component: "temp", directoryHint: .isDirectory)
    }
    
    
    func archiveFile(at url: URL, using compression: ArchiveCompression = .lzfse) throws -> URL {
        // https://developer.apple.com/documentation/accelerate/compressing_single_files
        let sourceFilePath = FilePath(url.path)
        guard let readFileStream = ArchiveByteStream.fileStream(
            path: sourceFilePath,
            mode: .readOnly,
            options: [],
            permissions: FilePermissions(rawValue: 0o644)
        ) else {
            throw ArchiveOperationError(message: "Error creating input file stream")
        }
        defer {
            try? readFileStream.close()
        }
        let archiveFilePath = FilePath(NSTemporaryDirectory() + url.lastPathComponent + ".\(compression.description)")
        guard let writeFileStream = ArchiveByteStream.fileStream(
            path: archiveFilePath,
            mode: .writeOnly,
            options: [.create],
            permissions: FilePermissions(rawValue: 0o644)
        ) else {
            throw ArchiveOperationError(message: "Error creating output file stream")
        }
        defer {
            try? writeFileStream.close()
        }
        guard let compressStream = ArchiveByteStream.compressionStream(
            using: compression,
            writingTo: writeFileStream
        ) else {
            throw ArchiveOperationError(message: "Error creating compression stream")
        }
        defer {
            try? compressStream.close()
        }
        do {
            _ = try ArchiveByteStream.process(readingFrom: readFileStream, writingTo: compressStream)
        } catch {
            throw ArchiveOperationError(message: "Error archiving file", underlyingError: error)
        }
        return URL(filePath: archiveFilePath)! // swiftlint:disable:this force_unwrapping
    }
}


extension Data {
    func compress(using compression: ArchiveCompression = .zlib) throws -> Data {
        guard let (readStream, writeStream) = ArchiveByteStream.sharedBufferPipe(capacity: self.count) else {
            throw FileManager.ArchiveOperationError(message: "Error creating byte streams")
        }
//        guard let readFileStream = ArchiveByteStream.fileStream(
//            path: sourceFilePath,
//            mode: .readOnly,
//            options: [],
//            permissions: FilePermissions(rawValue: 0o644)
//        ) else {
//            throw ArchiveOperationError(message: "Error creating input file stream")
//        }
        defer {
            try? writeStream.close()
        }
//        let archiveFilePath = FilePath(NSTemporaryDirectory() + url.lastPathComponent + ".\(compression.description)")
//        guard let writeFileStream = ArchiveByteStream.fileStream(
//            path: archiveFilePath,
//            mode: .writeOnly,
//            options: [.create],
//            permissions: FilePermissions(rawValue: 0o644)
//        ) else {
//            throw ArchiveOperationError(message: "Error creating output file stream")
//        }
//        defer {
//            try? writeFileStream.close()
//        }
        guard let compressStream = ArchiveByteStream.compressionStream(
            using: compression,
            writingTo: writeStream
        ) else {
            throw FileManager.ArchiveOperationError(message: "Error creating compression stream")
        }
        defer {
            try? compressStream.close()
        }
        do {
            _ = try ArchiveByteStream.process(readingFrom: readStream, writingTo: compressStream)
        } catch {
            throw FileManager.ArchiveOperationError(message: "Error archiving file", underlyingError: error)
        }
        // swiftlint:disable force_try
        do {
            let size = Int(try! readStream.seek(toOffset: 0, relativeTo: .end))
            _ = try! readStream.seek(toOffset: 0, relativeTo: .start)
            let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: size)
            let numRead = try! readStream.read(into: UnsafeMutableRawBufferPointer(buffer))
            print("NUM READ: \(numRead); SIZE: \(size)")
            return Data(bytesNoCopy: UnsafeMutableRawPointer(buffer.baseAddress)!, count: size, deallocator: .free)
        } catch {
            throw FileManager.ArchiveOperationError(message: "Unable to read buffer into Data", underlyingError: error)
        }
        // swiftlint:enable force_try
    }
}
