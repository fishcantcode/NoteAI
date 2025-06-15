import Foundation

 
struct PaginatedResponse<T: Decodable>: Decodable {
    let limit: Int
    let hasMore: Bool
    let data: [T]
    
    enum CodingKeys: String, CodingKey {
        case limit
        case hasMore = "has_more"
        case data
    }
}

 
typealias MessagesResponse = PaginatedResponse<Message>
typealias ConversationsResponse = PaginatedResponse<Conversation>
