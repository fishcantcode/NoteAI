import Foundation

struct KnowledgeDataset: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let permission: String
    let indexingTechnique: String?
    let createdAt: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, permission
        case indexingTechnique = "indexing_technique"
        case createdAt = "created_at"
    }
}

struct KnowledgeDatasetResponse: Codable {
    let data: [KnowledgeDataset]
    let hasMore: Bool
    let limit: Int
    let total: Int
    let page: Int
    
    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case limit, total, page
    }
}

struct CreateKnowledgeDatasetRequest: Codable {
    let name: String
    let description: String?             
    let indexingTechnique: String
    let permission: String               
    
     
    init(name: String, description: String? = nil, indexingTechnique: String = "high_quality", permission: String = "only_me") {
        self.name = name
        self.description = description
        self.indexingTechnique = indexingTechnique
        self.permission = permission
    }

    enum CodingKeys: String, CodingKey {
        case name, description, permission
        case indexingTechnique = "indexing_technique"
    }
}
