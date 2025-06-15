import Foundation

struct TranscriptionData: Codable {
    let segments: [TranscriptionSegment]
    let metadata: TranscriptionMetadata
    
    func toJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct TranscriptionMetadata: Codable {
    let title: String
    let date: Date
    let duration: Double
    let source: TranscriptionSource
}

enum TranscriptionSource: String, Codable {
    case realTime = "real_time"
    case mediaFile = "media_file"
}
