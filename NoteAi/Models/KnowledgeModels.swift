import Foundation

 

 
struct Dataset: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let permission: String?
    let indexing_technique: String?
    let created_at: TimeInterval?  

     
}

 
struct DatasetListResponse: Codable {
    let data: [Dataset]
    let has_more: Bool?
    let limit: Int?
    let total: Int?
    let page: Int?
}

 

struct APIDocument: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let indexing_status: String?
    let created_at: TimeInterval?

     
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: APIDocument, rhs: APIDocument) -> Bool {
        lhs.id == rhs.id
    }
}

struct DocumentListResponse: Codable {
    let data: [APIDocument]
    let has_more: Bool?
    let limit: Int?
    let total: Int?
    let page: Int?
}

 

 
