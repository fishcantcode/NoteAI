import Foundation

struct TranscriptionSegment: Identifiable, Hashable, Codable {
    let id = UUID()
    var text: String
    var timestamp: Double  
    var isFinal: Bool
     
}
