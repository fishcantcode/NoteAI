import Foundation

struct Conversation: Identifiable, Codable {
    var id: String
    var name: String
    var inputs: [String: String]?
    var status: String
    var introduction: String
    var createdAt: Int
    var updatedAt: Int
    
     
    var createdDate: Date {
        return Date(timeIntervalSince1970: TimeInterval(createdAt))
    }
    
    var updatedDate: Date {
        return Date(timeIntervalSince1970: TimeInterval(updatedAt))
    }
    
     
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: updatedDate)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case inputs
        case status
        case introduction
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
