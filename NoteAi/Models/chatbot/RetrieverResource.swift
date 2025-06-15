import Foundation

 
struct RetrieverResource: Codable, Identifiable, Equatable {
    let id: String
    let segment: String?
    let title: String?
    let url: String?
    let source: String?
    let score: Double?
    let hitCount: Int?
    let start: Int?
    let end: Int?
    let startOffset: Int?  
    let endOffset: Int?    
    let metadata: [String: String]?
    let semanticId: String?
    let semanticRanker: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case segment
        case title
        case url
        case source
        case score
        case hitCount = "hit_count"
        case start
        case end
        case startOffset = "start_offset"
        case endOffset = "end_offset"
        case metadata
        case semanticId = "semantic_id"
        case semanticRanker = "semantic_ranker"
    }
    
     
    init(from wrapper: RetrieverResourceWrapper?) {
        let resource = wrapper?.resources.first
        self.id = resource?.id ?? UUID().uuidString
        self.segment = resource?.segment
        self.title = resource?.title
        self.url = resource?.url
        self.source = resource?.source
        self.score = resource?.score
        self.hitCount = resource?.hitCount
        self.start = resource?.start
        self.end = resource?.end
        self.startOffset = resource?.startOffset
        self.endOffset = resource?.endOffset
        self.metadata = resource?.metadata
        self.semanticId = resource?.semanticId
        self.semanticRanker = resource?.semanticRanker
    }
}
