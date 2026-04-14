// ProgressPhoto.swift
// Stores metadata for a progress photo. The actual image is saved to the
// app's Documents/ProgressPhotos/ directory as a JPEG.
// SwiftData holds only the filename + AI analysis text.

import Foundation
import SwiftData
import UIKit

@Model
final class ProgressPhoto {
    var id: UUID
    var date: Date
    var filename: String        // relative filename inside Documents/ProgressPhotos/
    var bodyWeight: Double?     // lb at time of photo (optional)
    var aiAnalysis: String?     // Gemini-generated analysis
    var notes: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = .now,
        filename: String,
        bodyWeight: Double? = nil,
        aiAnalysis: String? = nil,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.filename = filename
        self.bodyWeight = bodyWeight
        self.aiAnalysis = aiAnalysis
        self.notes = notes
        self.createdAt = createdAt
    }
}

// MARK: - Local Storage Helper
enum ProgressPhotoStorage {
    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ProgressPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    static func save(_ image: UIImage) -> String? {
        let name = "\(UUID().uuidString).jpg"
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let url = directory.appendingPathComponent(name)
        do {
            try data.write(to: url)
            return name
        } catch {
            print("[ProgressPhotoStorage] Save error: \(error)")
            return nil
        }
    }

    static func load(filename: String) -> UIImage? {
        let url = directory.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    static func delete(filename: String) {
        let url = directory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
