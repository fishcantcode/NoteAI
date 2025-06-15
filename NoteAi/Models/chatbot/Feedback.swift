import Foundation

struct Feedback: Codable, Equatable {
    var rating: String?
    var content: String?
    
    enum CodingKeys: String, CodingKey {
        case rating
        case content
    }
}
